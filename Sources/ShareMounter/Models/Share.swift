import Foundation

/// A registered SMB share. Contains no secret material — the password lives in
/// the Keychain, keyed by `credentialKey`.
struct Share: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    /// Server host or address, e.g. "files.example.local" or "10.0.0.5".
    var host: String
    /// SMB share name, e.g. "public".
    var shareName: String
    /// Auth user (ignored when `isGuest`).
    var username: String
    var isGuest: Bool
    var autoMount: Bool

    init(id: UUID = UUID(),
         displayName: String = "",
         host: String = "",
         shareName: String = "",
         username: String = "",
         isGuest: Bool = false,
         autoMount: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.shareName = shareName
        self.username = username
        self.isGuest = isGuest
        self.autoMount = autoMount
    }

    /// The `smb://host/share` URL used for mounting. Credentials are never
    /// embedded in the URL — they are passed to NetFS separately.
    var smbURLString: String {
        let encodedShare = shareName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? shareName
        return "smb://\(host)/\(encodedShare)"
    }

    /// Stable Keychain account key for this share's password.
    var credentialKey: String { "\(username)@\(host)/\(shareName)" }

    /// Name shown in the menu / settings; falls back to the share name.
    var effectiveDisplayName: String {
        displayName.isEmpty ? (shareName.isEmpty ? "New Share" : shareName) : displayName
    }
}
