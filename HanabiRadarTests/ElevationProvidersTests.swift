import XCTest
import HanabiCore
@testable import HanabiRadar

final class ElevationProvidersTests: XCTestCase {

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [URL] = []
        var urls: [URL] { lock.lock(); defer { lock.unlock() }; return stored }
        func hit(_ url: URL) { lock.lock(); stored.append(url); lock.unlock() }
    }

    private struct FakeLoader: HTTPDataLoading {
        let body: String
        let status: Int
        let counter: Counter
        func data(from url: URL) async throws -> (Data, URLResponse) {
            counter.hit(url)
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
    }

    private struct Boom: ElevationProviding {
        func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? {
            throw ElevationProviderError.badResponse
        }
    }

    private struct Fixed: ElevationProviding {
        let value: Double
        func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? {
            ElevationSample(elevation: value, source: "fixed")
        }
    }

    private let tokyo = GeodeticCoordinate(latitude: 35.6586, longitude: 139.7454, altitude: 30)

    func testParsesGSIPayloadWithResolution() {
        let json = #"{"elevation":18.5,"hsrc":"1m（レーザ）"}"#
        let sample = ElevationParsing.parseGSI(Data(json.utf8))
        XCTAssertEqual(sample?.elevation, 18.5)
        XCTAssertEqual(sample?.resolutionMeters, 1)
        XCTAssertTrue(sample?.source.contains("国土地理院") == true)
    }

    func testGSINoDataSentinelIsNilNotZero() {
        let json = #"{"elevation":"-----","hsrc":"-----"}"#
        XCTAssertNil(ElevationParsing.parseGSI(Data(json.utf8)))
    }

    func testGSIGarbageIsNil() {
        XCTAssertNil(ElevationParsing.parseGSI(Data("not json".utf8)))
        XCTAssertNil(ElevationParsing.parseGSI(Data(#"{"elevation":true}"#.utf8)))
    }

    func testParsesOpenMeteoPayload() {
        let sample = ElevationParsing.parseOpenMeteo(Data(#"{"elevation":[46.0]}"#.utf8))
        XCTAssertEqual(sample?.elevation, 46.0)
        XCTAssertEqual(sample?.resolutionMeters, 90)
        XCTAssertNil(ElevationParsing.parseOpenMeteo(Data(#"{"elevation":[]}"#.utf8)))
    }

    func testLeadingMeters() {
        XCTAssertEqual(ElevationParsing.leadingMeters("5m（写真測量）"), 5)
        XCTAssertEqual(ElevationParsing.leadingMeters("10mDEM"), 10)
        XCTAssertNil(ElevationParsing.leadingMeters("-----"))
        XCTAssertNil(ElevationParsing.leadingMeters("abc"))
    }

    func testGSIURLCarriesLonLatAndJSON() throws {
        let url = try XCTUnwrap(GSIElevationProvider.url(for: tokyo))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "lon" }?.value, "139.745400")
        XCTAssertEqual(items.first { $0.name == "lat" }?.value, "35.658600")
        XCTAssertEqual(items.first { $0.name == "outtype" }?.value, "JSON")
    }

    func testGSISkipsRequestOutsideJapan() async throws {
        let counter = Counter()
        let provider = GSIElevationProvider(loader: FakeLoader(body: "{}", status: 200, counter: counter))
        let sample = try await provider.elevation(at: GeodeticCoordinate(latitude: 48.85, longitude: 2.35))
        XCTAssertNil(sample)
        XCTAssertTrue(counter.urls.isEmpty)
    }

    func testGSIHTTPErrorThrows() async {
        let provider = GSIElevationProvider(loader: FakeLoader(body: "", status: 500, counter: Counter()))
        do {
            _ = try await provider.elevation(at: tokyo)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ElevationProviderError, .badResponse)
        }
    }

    func testFallbackSkipsFailureAndNil() async throws {
        let chain = FallbackElevationProvider(providers: [Boom(), Fixed(value: 12)])
        let sample = try await chain.elevation(at: tokyo)
        XCTAssertEqual(sample?.elevation, 12)
        let none = try await FallbackElevationProvider(providers: [Boom()]).elevation(at: tokyo)
        XCTAssertNil(none)
    }

    func testCacheCoalescesNearbyLookupsAndRemembersNoData() async throws {
        let counter = Counter()
        let json = #"{"elevation":"-----","hsrc":"-----"}"#
        let provider = CachingElevationProvider(
            GSIElevationProvider(loader: FakeLoader(body: json, status: 200, counter: counter))
        )
        _ = try await provider.elevation(at: tokyo)
        _ = try await provider.elevation(at: GeodeticCoordinate(latitude: 35.65861, longitude: 139.74541))
        XCTAssertEqual(counter.urls.count, 1)
    }

    func testCacheDoesNotRememberFailures() async {
        let counter = Counter()
        let provider = CachingElevationProvider(
            GSIElevationProvider(loader: FakeLoader(body: "", status: 503, counter: counter))
        )
        _ = try? await provider.elevation(at: tokyo)
        _ = try? await provider.elevation(at: tokyo)
        XCTAssertEqual(counter.urls.count, 2)
    }
}
