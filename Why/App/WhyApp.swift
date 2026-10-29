import SwiftUI

@main
struct WhyApp: App {
    @StateObject private var monitor = SystemMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor)
        } label: {
            WhyLogoView()
                .accessibilityLabel("Why? — Your Mac, explained.")
        }
        .menuBarExtraStyle(.window)
    }
}
