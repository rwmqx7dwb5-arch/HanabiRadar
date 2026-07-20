import SwiftUI
import WeatherKit

/// Loads Apple's required WeatherKit attribution (the "Apple Weather" combined mark and a
/// link to Apple's legal / data-sources page). Apple requires this wherever WeatherKit
/// data is shown (§11, §20, §27). The real attribution comes from
/// `WeatherService.shared.attribution`; when that isn't available (no entitlement, mock /
/// UI-test mode, or a network failure) the view degrades to a plain "Apple Weather" label
/// plus Apple's known legal-attribution URL, so it never blocks or shows a dead control.
@MainActor
final class WeatherAttributionModel: ObservableObject {
    struct Info: Equatable {
        var lightMarkURL: URL?
        var darkMarkURL: URL?
        var legalURL: URL
    }

    /// Apple's documented legal-attribution page, used as a fallback link when the
    /// attribution API can't be reached (e.g. unsigned CI builds without the entitlement).
    static let fallbackLegalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    @Published private(set) var info: Info?
    @Published private(set) var usedFallback = false

    /// Fetches the attribution, or falls back. `useMock` short-circuits the real call so
    /// the Simulator / UI tests never hit the network or require an entitlement.
    func load(useMock: Bool) async {
        if useMock {
            info = Info(lightMarkURL: nil, darkMarkURL: nil, legalURL: Self.fallbackLegalURL)
            usedFallback = true
            return
        }
        do {
            let attribution = try await WeatherService.shared.attribution
            info = Info(
                lightMarkURL: attribution.combinedMarkLightURL,
                darkMarkURL: attribution.combinedMarkDarkURL,
                legalURL: attribution.legalPageURL
            )
        } catch {
            info = Info(lightMarkURL: nil, darkMarkURL: nil, legalURL: Self.fallbackLegalURL)
            usedFallback = true
        }
    }
}

/// Small inline Apple Weather attribution (mark + legal link). Drop this on any screen
/// that displays WeatherKit-derived data.
struct WeatherAttributionView: View {
    @StateObject private var model = WeatherAttributionModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            if let info = model.info {
                mark(info)
                Spacer(minLength: 8)
                Link("データソース", destination: info.legalURL)
                    .font(.footnote)
            } else {
                ProgressView()
                Spacer()
            }
        }
        .task { await model.load(useMock: AppLaunch.useMockSensors) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Weather")
        .accessibilityIdentifier("weather-attribution")
    }

    @ViewBuilder
    private func mark(_ info: WeatherAttributionModel.Info) -> some View {
        let markURL = colorScheme == .dark ? info.darkMarkURL : info.lightMarkURL
        if let markURL {
            AsyncImage(url: markURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text(verbatim: "Apple Weather").font(.footnote)
            }
            .frame(height: 16)
            .accessibilityHidden(true)
        } else {
            Text(verbatim: "Apple Weather")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    List {
        Section("気象データ") {
            WeatherAttributionView()
        }
    }
}
