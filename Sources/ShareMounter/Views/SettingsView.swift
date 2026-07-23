import SwiftUI

/// Register and edit shares. Edits apply live (macOS-style, no Save button);
/// the password is committed to the Keychain on Return or when the field loses
/// focus, and is never displayed back.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var shares: [Share] = []
    @State private var selection: UUID?
    @State private var password: String = ""
    @State private var launchAtLogin = false
    @FocusState private var passwordFocused: Bool

    var body: some View {
        // The footer is a VStack sibling, not a `.safeAreaInset` on the split
        // view: a bottom inset applied to a NavigationSplitView does not shorten
        // the sidebar column, so the sidebar keeps drawing full-height and its
        // own bottom bar (the +/- buttons) ends up hidden behind the footer.
        VStack(spacing: 0) {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 260)
            } detail: {
                detail
                    .navigationTitle(selectedShareName)
            }
            Divider()
            footer
        }
        .frame(minWidth: 620, minHeight: 460)
        .onAppear {
            shares = model.shares
            launchAtLogin = model.isLoginItemEnabled
        }
        .onChange(of: selection) { _ in
            commitPassword()
            password = ""
        }
        .onDisappear { commitPassword() }
    }

    private var selectedShareName: String {
        shares.first(where: { $0.id == selection })?.effectiveDisplayName ?? "Shares"
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(shares) { share in
                Text(share.effectiveDisplayName).tag(share.id)
            }
            .onMove { indices, newOffset in
                shares.move(fromOffsets: indices, toOffset: newOffset)
                persist()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 2) {
                Button { addShare() } label: { Image(systemName: "plus") }
                    .help("Add a share")
                Button { removeSelected() } label: { Image(systemName: "minus") }
                    .disabled(selection == nil)
                    .help("Remove the selected share")
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }

    // MARK: - Detail

    @ViewBuilder private var detail: some View {
        if let index = shares.firstIndex(where: { $0.id == selection }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    labeledField("Display name", stringBinding(index, \.displayName))
                    labeledField("Server host", stringBinding(index, \.host),
                                 prompt: "files.example.local")
                    labeledField("Share name", stringBinding(index, \.shareName),
                                 prompt: "public")
                    Toggle("Guest connection", isOn: boolBinding(index, \.isGuest))
                    if !shares[index].isGuest {
                        labeledField("Username", stringBinding(index, \.username))
                        passwordField(index)
                    }
                    Toggle("Auto-mount at login", isOn: boolBinding(index, \.autoMount))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Select or add a share")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Launch at login", isOn: launchBinding)
            Spacer()
            Text("v\(AppInfo.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func labeledField(_ label: String, _ text: Binding<String>, prompt: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", text: text, prompt: prompt.map(Text.init))
                .textFieldStyle(.roundedBorder)
        }
    }

    /// Password field with an explicit status line, so it's clear whether a
    /// credential is stored — the field itself never shows the saved password.
    @ViewBuilder
    private func passwordField(_ index: Int) -> some View {
        let stored = model.hasStoredPassword(for: shares[index])
        VStack(alignment: .leading, spacing: 4) {
            Text("Password").font(.caption).foregroundStyle(.secondary)
            SecureField("", text: $password,
                        prompt: Text(stored ? "Leave blank to keep the saved password" : "Required"))
                .textFieldStyle(.roundedBorder)
                .focused($passwordFocused)
                .onSubmit { commitPassword() }
                .onChange(of: passwordFocused) { focused in
                    if !focused { commitPassword() }
                }
            if !password.isEmpty {
                Label("Press Return to save it to the Keychain", systemImage: "return")
                    .font(.caption).foregroundStyle(.secondary)
            } else if stored {
                Label("Password saved in Keychain", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Label("No password saved yet", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Bindings (live-apply)

    private var launchBinding: Binding<Bool> {
        Binding(get: { launchAtLogin },
                set: { newValue in launchAtLogin = newValue; model.setLoginItem(newValue) })
    }

    private func stringBinding(_ index: Int, _ keyPath: WritableKeyPath<Share, String>) -> Binding<String> {
        Binding(get: { shares[index][keyPath: keyPath] },
                set: { shares[index][keyPath: keyPath] = $0; persist() })
    }

    private func boolBinding(_ index: Int, _ keyPath: WritableKeyPath<Share, Bool>) -> Binding<Bool> {
        Binding(get: { shares[index][keyPath: keyPath] },
                set: { shares[index][keyPath: keyPath] = $0; persist() })
    }

    // MARK: - Actions

    /// Persist the current metadata/order to disk and reflect it in the menu.
    private func persist() { model.updateShares(shares) }

    private func commitPassword() {
        guard let index = shares.firstIndex(where: { $0.id == selection }) else { return }
        guard !password.isEmpty, !shares[index].isGuest else { return }
        model.setPassword(password, for: shares[index])
        password = ""
    }

    private func addShare() {
        let share = Share(displayName: "New Share")
        shares.append(share)
        selection = share.id
        password = ""
        persist()
    }

    private func removeSelected() {
        guard let id = selection, let index = shares.firstIndex(where: { $0.id == id }) else { return }
        model.removePassword(for: shares[index])
        shares.remove(at: index)
        selection = nil
        password = ""
        persist()
    }
}
