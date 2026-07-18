import AppKit
import SwiftUI

enum WindowID {
    static let settings = "settings"
}

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

        // A plain Window (opened via openWindow) rather than the SwiftUI
        // `Settings` scene: the imperative "open Settings" path relies on a
        // private AppKit selector that is unreliable across macOS versions.
        Window("ShareMounter Settings", id: WindowID.settings) {
            SettingsView()
                .environmentObject(appDelegate.model)
                .frame(minWidth: 560, minHeight: 440)
        }
        .windowResizability(.contentSize)
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
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)

        // Keep the menu in sync when a volume mounts/unmounts out from under us
        // (e.g. an eject from Finder), so the app's state can't drift.
        for name in [NSWorkspace.didMountNotification,
                     NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification] {
            workspaceCenter.addObserver(
                self, selector: #selector(volumesChanged), name: name, object: nil)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification, object: nil)
    }

    @objc private func didWake(_ notification: Notification) {
        Task { @MainActor in await model.autoMountAll() }
    }

    @objc private func volumesChanged(_ notification: Notification) {
        Task { @MainActor in model.reload() }
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
