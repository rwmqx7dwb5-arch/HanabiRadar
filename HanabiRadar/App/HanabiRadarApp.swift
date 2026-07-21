import SwiftUI
import UIKit
import SwiftData

@main
struct HanabiRadarApp: App {
    /// The persistent store for measurement history. UI tests use an in-memory store so a
    /// run never reads or writes the device's real history.
    let modelContainer: ModelContainer

    init() {
        if AppLaunch.isUITest {
            // Deterministic UI tests: no animations.
            UIView.setAnimationsEnabled(false)
        }
        let schema = MeasurementSessionRecord.self
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: AppLaunch.isUITest)
            modelContainer = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Fall back to an in-memory store so a corrupt or inaccessible on-disk store
            // never bricks the app; history simply won't persist across launches.
            modelContainer = try! ModelContainer(
                for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
