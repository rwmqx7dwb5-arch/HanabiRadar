import SwiftUI
import MapKit
import HanabiCore

/// Lets the user set the observer location by hand when Core Location is denied (§21). The
/// map needs no location permission to pan, so this works precisely when GPS does not: the
/// user lines a fixed crosshair up with where they are standing and confirms. The chosen
/// point (with an optional altitude) is fed into the capture timeline as the observer fix so
/// the estimator can still produce absolute positions — with a manual-grade accuracy so the
/// error bars stay honest.
struct ManualLocationView: View {
    var initialCoordinate: CLLocationCoordinate2D
    var onConfirm: (GeodeticCoordinate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    @State private var centerCoordinate: CLLocationCoordinate2D
    @State private var altitudeText = "0"

    init(
        initialCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 35.681, longitude: 139.767),
        onConfirm: @escaping (GeodeticCoordinate) -> Void
    ) {
        self.initialCoordinate = initialCoordinate
        self.onConfirm = onConfirm
        let region = MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        _cameraPosition = State(initialValue: .region(region))
        _centerCoordinate = State(initialValue: initialCoordinate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition)
                    .onMapCameraChange(frequency: .continuous) { context in
                        centerCoordinate = context.region.center
                    }
                    .ignoresSafeArea(edges: .bottom)
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.blue)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .safeAreaInset(edge: .bottom) { controls }
            .navigationTitle("観測地点を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .accessibilityIdentifier("manual-location-view")
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Text("地図を動かして、立っている場所に十字を合わせてください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(verbatim: String(format: "%.5f, %.5f", centerCoordinate.latitude, centerCoordinate.longitude))
                .font(.footnote.monospaced())
            HStack {
                Text("標高 (m)")
                TextField("0", text: $altitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .accessibilityIdentifier("manual-altitude-field")
            }
            Button("この位置を使う") {
                let altitude = Double(altitudeText) ?? 0
                onConfirm(GeodeticCoordinate(
                    latitude: centerCoordinate.latitude,
                    longitude: centerCoordinate.longitude,
                    altitude: altitude
                ))
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("confirm-manual-location")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}
