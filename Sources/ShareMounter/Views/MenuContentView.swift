import AppKit
import SwiftUI

/// The dropdown shown from the menu-bar icon: one submenu per share with
/// explicit Mount / Unmount / Reveal actions (so a share can't be unmounted by
/// an accidental single click), plus settings and quit.
struct MenuContentView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.statuses.isEmpty {
            Text("No shares configured")
            Button("Add a share…") { openSettings() }
            Divider()
        } else {
            ForEach(model.statuses) { status in
                Menu("\(glyph(for: status.state))  \(status.share.effectiveDisplayName)") {
                    Button("Mount") { model.mount(status.share) }
                        .disabled(!canMount(status.state))
                    Button("Unmount") { model.unmount(status.share) }
                        .disabled(!canUnmount(status.state))
                    if case .mounted(let path) = status.state {
                        Divider()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        }
                    }
                    if case .error(let message) = status.state {
                        Divider()
                        Text(message)
                    }
                }
            }
            Divider()
        }

        Button("About ShareMounter") { showAbout() }
        Button("Settings…") { openSettings() }
            .keyboardShortcut(",", modifiers: .command)

        Divider()

        Text("Version \(AppInfo.version)")
        Button("Quit ShareMounter") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    /// Bring the app forward and open the settings window. Setting `.regular`
    /// first lets the (LSUIElement) app show a real, focusable window.
    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.settings)
    }

    /// Show the standard About panel, passing the app icon explicitly so it
    /// appears (the panel reads it from the bundle's AppIcon in a packaged app).
    private func showAbout() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if let icon = NSApp.applicationIconImage {
            options[.applicationIcon] = icon
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    private func glyph(for state: MountState) -> String {
        switch state {
        case .mounted: return "✓"
        case .mounting, .unmounting: return "…"
        case .error: return "⚠"
        case .unmounted: return "○"
        }
    }

    private func canMount(_ state: MountState) -> Bool {
        switch state {
        case .unmounted, .error: return true
        default: return false
        }
    }

    private func canUnmount(_ state: MountState) -> Bool {
        if case .mounted = state { return true }
        return false
    }
}
