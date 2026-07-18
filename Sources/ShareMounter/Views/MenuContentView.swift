import SwiftUI

/// The dropdown shown from the menu-bar icon: one row per share (click toggles
/// mount/unmount), plus settings and quit.
struct MenuContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if model.statuses.isEmpty {
            Text("No shares configured")
            Button("Add a share…") { openSettingsWindow() }
            Divider()
        } else {
            ForEach(model.statuses) { status in
                Button {
                    model.toggle(status.share)
                } label: {
                    Text("\(glyph(for: status.state))  \(status.share.effectiveDisplayName)")
                }
                .disabled(isBusy(status.state))
            }
            Divider()
        }

        Button("Settings…") { openSettingsWindow() }
            .keyboardShortcut(",", modifiers: .command)
        Button("Quit ShareMounter") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    private func glyph(for state: MountState) -> String {
        switch state {
        case .mounted: return "✓"
        case .mounting, .unmounting: return "…"
        case .error: return "⚠"
        case .unmounted: return "○"
        }
    }

    private func isBusy(_ state: MountState) -> Bool {
        switch state {
        case .mounting, .unmounting: return true
        default: return false
        }
    }
}
