import Foundation
import CoreLocation
import HanabiCore
import HanabiCapture

/// Core Location source for observer position and true heading. Timestamps are
/// normalized from wall-clock onto the common uptime axis.
final class DeviceLocationCaptureService: NSObject, LocationCaptureService, CLLocationManagerDelegate {
    weak var sink: CaptureSink?
    private(set) var isRunning = false

    private let manager = CLLocationManager()
    private var normalizer = TimelineNormalizer()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() throws {
        normalizer = UptimeClock.wallClockNormalizer()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        isRunning = true
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        isRunning = false
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = GeodeticCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude
        )
        let sample = LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy
        )
        let time = normalizer.normalize(sourceSeconds: location.timestamp.timeIntervalSinceReferenceDate)
        DispatchQueue.main.async {
            self.sink?.ingest(location: Timed(time: time, value: sample))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let sample = HeadingSample(
            trueHeadingDegrees: newHeading.trueHeading,
            accuracyDegrees: newHeading.headingAccuracy
        )
        let time = normalizer.normalize(sourceSeconds: newHeading.timestamp.timeIntervalSinceReferenceDate)
        DispatchQueue.main.async {
            self.sink?.ingest(heading: Timed(time: time, value: sample))
        }
    }
}
