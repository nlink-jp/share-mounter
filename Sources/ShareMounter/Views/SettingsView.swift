import SwiftUI

/// Register and edit shares. Passwords are written to the Keychain on Save and
/// are never displayed back.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var shares: [Share] = []
    @State private var selection: UUID?
    @State private var password: String = ""
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                sidebar
                    .frame(width: 190)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack {
                Toggle("Launch at login", isOn: launchBinding)
                Spacer()
            }
            .padding(8)
        }
        .onAppear {
            shares = model.shares
            launchAtLogin = model.isLoginItemEnabled
        }
        .onChange(of: selection) { _ in password = "" }
    }

    private var launchBinding: Binding<Bool> {
        Binding(get: { launchAtLogin },
                set: { newValue in launchAtLogin = newValue; model.setLoginItem(newValue) })
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(shares) { share in
                    Text(share.effectiveDisplayName).tag(share.id)
                }
            }
            Divider()
            HStack(spacing: 8) {
                Button { addShare() } label: { Image(systemName: "plus") }
                Button { removeSelected() } label: { Image(systemName: "minus") }
                    .disabled(selection == nil)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(6)
        }
    }

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
                    HStack {
                        Spacer()
                        Button("Save") { save(index) }
                            .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top, 4)
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
            if !password.isEmpty {
                Label("Will be saved to the Keychain when you click Save",
                      systemImage: "pencil.circle")
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

    // MARK: - Bindings

    private func stringBinding(_ index: Int, _ keyPath: WritableKeyPath<Share, String>) -> Binding<String> {
        Binding(get: { shares[index][keyPath: keyPath] },
                set: { shares[index][keyPath: keyPath] = $0 })
    }

    private func boolBinding(_ index: Int, _ keyPath: WritableKeyPath<Share, Bool>) -> Binding<Bool> {
        Binding(get: { shares[index][keyPath: keyPath] },
                set: { shares[index][keyPath: keyPath] = $0 })
    }

    // MARK: - Actions

    private func addShare() {
        let share = Share(displayName: "New Share")
        shares.append(share)
        selection = share.id
        password = ""
    }

    private func removeSelected() {
        guard let id = selection, let index = shares.firstIndex(where: { $0.id == id }) else { return }
        shares.remove(at: index)
        selection = nil
        model.saveShares(shares)
    }

    private func save(_ index: Int) {
        // Save the password first so the re-render triggered by saveShares picks
        // up the new "saved in Keychain" state immediately.
        if !password.isEmpty, !shares[index].isGuest {
            model.setPassword(password, for: shares[index])
        }
        model.saveShares(shares)
        password = ""
    }
}
