import SwiftUI
import UIKit

@main
struct HanabiRadarApp: App {
    init() {
        if AppLaunch.isUITest {
            // Deterministic UI tests: no animations.
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
