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
            Form {
                TextField("Display name", text: stringBinding(index, \.displayName))
                TextField("Server host", text: stringBinding(index, \.host),
                          prompt: Text("files.example.local"))
                TextField("Share name", text: stringBinding(index, \.shareName),
                          prompt: Text("public"))
                Toggle("Guest connection", isOn: boolBinding(index, \.isGuest))
                if !shares[index].isGuest {
                    TextField("Username", text: stringBinding(index, \.username))
                    SecureField("Password", text: $password,
                                prompt: Text("stored in Keychain"))
                }
                Toggle("Auto-mount at login", isOn: boolBinding(index, \.autoMount))
                HStack {
                    Spacer()
                    Button("Save") { save(index) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .formStyle(.grouped)
        } else {
            Text("Select or add a share")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        model.saveShares(shares)
        if !password.isEmpty, !shares[index].isGuest {
            model.setPassword(password, for: shares[index])
        }
        password = ""
    }
}
