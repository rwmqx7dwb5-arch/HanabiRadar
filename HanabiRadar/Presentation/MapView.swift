import SwiftUI
import MapKit
import HanabiCore

/// The kind of point plotted on the result map (§16.3).
enum BurstMapPointKind: String, Sendable, Equatable {
    case observer     // 観測地点
    case burst        // 爆発地点（推定・空中）
    case subpoint     // 爆発地点の直下（推定）
}

struct BurstMapPoint: Identifiable, Equatable {
    let id: String
    let kind: BurstMapPointKind
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Pure, testable derivation of what the result map should show: the observer, the burst,
/// its subpoint, and the horizontal 95% circle. Keeping this out of the view means the
/// map's content is unit-tested rather than trusted to SwiftUI.
struct BurstMapModel: Equatable {
    let points: [BurstMapPoint]
    let circleCenterLatitude: Double
    let circleCenterLongitude: Double
    let circleRadiusMeters: Double

    var circleCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: circleCenterLatitude, longitude: circleCenterLongitude)
    }

    static func build(
        observer: GeodeticCoordinate,
        estimate: BurstEstimate,
        uncertainty: UncertaintyResult
    ) -> BurstMapModel {
        BurstMapModel(
            points: [
                BurstMapPoint(id: "observer", kind: .observer, latitude: observer.latitude, longitude: observer.longitude),
                BurstMapPoint(id: "burst", kind: .burst, latitude: estimate.burst.latitude, longitude: estimate.burst.longitude),
                BurstMapPoint(id: "subpoint", kind: .subpoint, latitude: estimate.subpoint.latitude, longitude: estimate.subpoint.longitude)
            ],
            circleCenterLatitude: uncertainty.centerLatitude,
            circleCenterLongitude: uncertainty.centerLongitude,
            circleRadiusMeters: uncertainty.horizontalEllipse.semiMajorMeters
        )
    }

    /// A region that comfortably contains every point (with padding and a sane minimum).
    var region: MKCoordinateRegion {
        let lats = points.map(\.latitude) + [circleCenterLatitude]
        let lons = points.map(\.longitude) + [circleCenterLongitude]
        let minLat = lats.min() ?? 0, maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0, maxLon = lons.max() ?? 0
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: Swift.max((maxLat - minLat) * 1.6, 0.01),
            longitudeDelta: Swift.max((maxLon - minLon) * 1.6, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// Thin map view over `BurstMapModel`. Labels every point as an estimate; the 95% circle
/// conveys the honest horizontal uncertainty rather than a sharp point (§4, §14).
struct BurstMapView: View {
    let model: BurstMapModel

    var body: some View {
        Map(initialPosition: .region(model.region)) {
            ForEach(model.points) { point in
                Marker(label(point), systemImage: symbol(point), coordinate: point.coordinate)
                    .tint(tint(point))
            }
            MapCircle(center: model.circleCenter, radius: model.circleRadiusMeters)
                .foregroundStyle(.orange.opacity(0.18))
                .stroke(.orange, lineWidth: 1.5)
        }
        .navigationTitle("地図")
        .accessibilityIdentifier("map-view")
    }

    private func label(_ point: BurstMapPoint) -> LocalizedStringKey {
        switch point.kind {
        case .observer: return "観測地点"
        case .burst: return "爆発地点（推定）"
        case .subpoint: return "直下（推定）"
        }
    }

    private func symbol(_ point: BurstMapPoint) -> String {
        switch point.kind {
        case .observer: return "location.fill"
        case .burst: return "sparkles"
        case .subpoint: return "mappin.and.ellipse"
        }
    }

    private func tint(_ point: BurstMapPoint) -> Color {
        switch point.kind {
        case .observer: return .blue
        case .burst: return .orange
        case .subpoint: return .red
        }
    }
}

/// Demo map built from the sample estimate.
struct DemoMapScreen: View {
    private let sample = DemoEstimate.sample()

    var body: some View {
        BurstMapView(model: BurstMapModel.build(
            observer: sample.observer, estimate: sample.estimate, uncertainty: sample.uncertainty
        ))
    }
}

#Preview {
    NavigationStack {
        DemoMapScreen()
    }
}
