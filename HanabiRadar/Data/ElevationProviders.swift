import Foundation
import HanabiCore

/// Minimal network seam so the elevation adapters are testable without real I/O.
protocol HTTPDataLoading: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

/// `URLSession` adapter (a wrapper, because `URLSession.data(from:delegate:)` has an extra
/// defaulted parameter and so does not satisfy the protocol requirement directly).
struct URLSessionLoader: HTTPDataLoading {
    let session: URLSession
    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }
}

enum ElevationProviderError: Error, Equatable {
    case badResponse
}

/// Pure response parsing, kept separate from I/O so it is unit-tested with canned payloads.
enum ElevationParsing {

    /// GSI (国土地理院) `getelevation.php` payload: `{"elevation":18.5,"hsrc":"1m（レーザ）"}`.
    /// Outside DEM coverage (open sea, abroad) the service returns the string `"-----"`,
    /// which maps to `nil` — "no ground elevation here" — never to a fabricated 0 m.
    static func parseGSI(_ data: Data) -> ElevationSample? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let number = object["elevation"] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue
        guard value.isFinite else { return nil }
        let hsrc = object["hsrc"] as? String
        return ElevationSample(
            elevation: value,
            source: hsrc.map { "国土地理院 標高API（\($0)）" } ?? "国土地理院 標高API",
            resolutionMeters: hsrc.flatMap(leadingMeters),
            dataVersion: hsrc
        )
    }

    /// Open-Meteo Elevation API payload: `{"elevation":[30.0]}` (Copernicus DEM, ~90 m).
    static func parseOpenMeteo(_ data: Data) -> ElevationSample? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let values = object["elevation"] as? [NSNumber],
              let first = values.first, first.doubleValue.isFinite else { return nil }
        return ElevationSample(
            elevation: first.doubleValue,
            source: "Open-Meteo Elevation API（Copernicus DEM）",
            resolutionMeters: 90,
            dataVersion: nil
        )
    }

    /// "5m（写真測量）" -> 5, "10mDEM" -> 10, "-----" -> nil.
    static func leadingMeters(_ text: String) -> Double? {
        let digits = text.prefix { $0.isNumber || $0 == "." }
        guard digits.isEmpty == false, text.dropFirst(digits.count).hasPrefix("m") else { return nil }
        return Double(digits)
    }
}

/// Ground elevation from the GSI elevation service (free, keyless, Japan-only DEM).
/// Attribution (出典) is carried in `ElevationSample.source`.
struct GSIElevationProvider: ElevationProviding {
    let loader: HTTPDataLoading
    static let endpoint = "https://cyberjapandata2.gsi.go.jp/general/dem/scripts/getelevation.php"

    /// Generous bounding box around Japan, used only to skip pointless requests; the
    /// service itself decides real coverage by returning `"-----"`.
    static func isPlausiblyInJapan(_ c: GeodeticCoordinate) -> Bool {
        (20.0...46.5).contains(c.latitude) && (122.5...154.5).contains(c.longitude)
    }

    static func url(for c: GeodeticCoordinate) -> URL? {
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "lon", value: String(format: "%.6f", c.longitude)),
            URLQueryItem(name: "lat", value: String(format: "%.6f", c.latitude)),
            URLQueryItem(name: "outtype", value: "JSON")
        ]
        return components?.url
    }

    func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? {
        guard Self.isPlausiblyInJapan(coordinate), let url = Self.url(for: coordinate) else { return nil }
        let (data, response) = try await loader.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ElevationProviderError.badResponse }
        return ElevationParsing.parseGSI(data)
    }
}

/// Worldwide fallback (Copernicus DEM via Open-Meteo). NOTE: Open-Meteo's free tier is for
/// non-commercial use; a commercial release needs their paid plan — see KNOWN_LIMITATIONS.
struct OpenMeteoElevationProvider: ElevationProviding {
    let loader: HTTPDataLoading
    static let endpoint = "https://api.open-meteo.com/v1/elevation"

    static func url(for c: GeodeticCoordinate) -> URL? {
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.6f", c.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.6f", c.longitude))
        ]
        return components?.url
    }

    func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? {
        guard let url = Self.url(for: coordinate) else { return nil }
        let (data, response) = try await loader.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ElevationProviderError.badResponse }
        return ElevationParsing.parseOpenMeteo(data)
    }
}

/// Tries providers in order; `nil` or a thrown error moves on to the next. If none yields a
/// sample the result is `nil` (MSL / relative height only — no fabricated AGL).
struct FallbackElevationProvider: ElevationProviding {
    let providers: [ElevationProviding]

    func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? {
        for provider in providers {
            if let sample = try? await provider.elevation(at: coordinate) { return sample }
        }
        return nil
    }
}

/// Memoizes results (including "no data") per ~11 m cell so a session of many bursts, or a
/// repeat measurement from the same spot, does not hammer the network. Failures (throws) are
/// not cached so a transient outage can recover.
final class CachingElevationProvider: ElevationProviding, @unchecked Sendable {
    private let base: ElevationProviding
    private let lock = NSLock()
    private var cache: [String: ElevationSample?] = [:]

    init(_ base: ElevationProviding) { self.base = base }

    private func key(_ c: GeodeticCoordinate) -> String {
        String(format: "%.4f,%.4f", c.latitude, c.longitude)
    }

    func elevation(at coordinate: GeodeticCoordinate) async throws -> ElevationSample? {
        let k = key(coordinate)
        lock.lock()
        if let hit = cache[k] { lock.unlock(); return hit }
        lock.unlock()
        let value = try await base.elevation(at: coordinate)
        lock.lock()
        cache[k] = .some(value)
        lock.unlock()
        return value
    }
}

enum ElevationProviderFactory {
    /// Real providers need the network; UI tests and `-mock-sensors` get none so results stay
    /// deterministic and offline. Global fallback is OFF by default (commercial-terms caveat).
    static func makeDefault(allowGlobalFallback: Bool = false) -> ElevationProviding? {
        if AppLaunch.useMockSensors { return nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        let loader = URLSessionLoader(session: URLSession(configuration: configuration))
        var chain: [ElevationProviding] = [GSIElevationProvider(loader: loader)]
        if allowGlobalFallback { chain.append(OpenMeteoElevationProvider(loader: loader)) }
        return CachingElevationProvider(FallbackElevationProvider(providers: chain))
    }
}
