import SwiftUI

@main
struct AtomicApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.model)
        }
        .onChange(of: scenePhase) { phase in
            // Coming back to the foreground is the cheapest place to refresh; the
            // old background fetch API is deprecated and a sideloaded build has no
            // Background App Refresh budget to rely on anyway.
            if phase == .active {
                appDelegate.model.refresh()
            }
        }
    }
}
