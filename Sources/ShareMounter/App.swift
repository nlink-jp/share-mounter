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

    private let networkMonitor = NetworkMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reflect any volumes already mounted at launch, then auto-mount the
        // flagged shares (each gated on the server becoming reachable).
        model.reload()
        Task { await model.autoMountAll() }

        // Re-mount when the network path comes back (Wi-Fi/VPN reconnect).
        networkMonitor.onBecameSatisfied = { [weak self] in
            Task { @MainActor in await self?.model.autoMountAll() }
        }
        networkMonitor.start()

        // Re-mount after waking from sleep.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification, object: nil)
    }

    @objc private func didWake(_ notification: Notification) {
        Task { @MainActor in await model.autoMountAll() }
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
