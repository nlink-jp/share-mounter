import AppKit
import SwiftUI

@main
struct ShareMounterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(appDelegate.model)
        } label: {
            Image(systemName: "externaldrive.connected.to.line.below")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.model)
                .frame(minWidth: 560, minHeight: 420)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var model: AppModel = AppModel(
        store: ShareStore(fileURL: ShareStore.defaultFileURL()),
        credentials: KeychainCredentialStore(),
        mounter: NetFSMounter(),
        inventory: SMBMountInventory())

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reflect any volumes already mounted at launch.
        model.reload()

        // Phase 2 wires the rest of the "stays mounted" behavior here:
        //   - SMAppService login registration (launch at login)
        //   - reachability-gated auto-mount of `model.autoMountShares()`
        //   - NWPathMonitor + wake-from-sleep notifications → re-mount
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification, object: nil)
    }

    /// Return to the menu-bar-only activation policy once no window is visible.
    @objc private func windowClosed(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeKey }
            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

/// Open the SwiftUI `Settings` scene from an imperative context (macOS 13+).
@MainActor
func openSettingsWindow() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
}
