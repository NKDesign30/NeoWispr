import SwiftUI

@main
struct NeoWisprApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var env = AppEnvironment()
    @StateObject private var updaterController = UpdaterController()

    var body: some Scene {
        MenuBarExtra("NeoWispr", systemImage: env.recordingController.state.statusIcon) {
            MenuBarView()
                .environment(env)
                .environment(env.recordingController)
                .environment(env.permissionGate)
                .environment(env.parakeetModelStore)
                .environmentObject(updaterController)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(env)
                .environment(env.recordingController)
                .environment(env.permissionGate)
                .environment(env.powerModeStore)
                .environment(env.parakeetModelStore)
        }
    }
}
