import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var appModel: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.appModel?.openSettingsWindow()
        return true
    }
}

@main
struct SimDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel: AppModel

    init() {
        let appModel = AppModel()
        _appModel = StateObject(wrappedValue: appModel)
        AppDelegate.appModel = appModel
    }

    var body: some Scene {
        MenuBarExtra("SimDeck", systemImage: "camera.viewfinder") {
            MenuBarView()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appModel.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
