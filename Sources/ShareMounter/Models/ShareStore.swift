import Foundation

/// Persists the list of shares as JSON. Holds no secrets (passwords live in the
/// Keychain). The storage location is injected so it can be pointed at a temp
/// directory in tests.
struct ShareStore {
    let fileURL: URL

    init(fileURL: URL) { self.fileURL = fileURL }

    /// `~/Library/Application Support/<bundleID>/shares.json`.
    static func defaultFileURL(bundleID: String = "jp.nlink.share-mounter") -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("shares.json")
    }

    /// Load shares. Returns `[]` when the file is missing, unreadable, or corrupt
    /// — never throws, so a bad file can't wedge app launch.
    func load() -> [Share] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Share].self, from: data)) ?? []
    }

    /// Persist shares, creating the parent directory as needed.
    func save(_ shares: [Share]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(shares)
        try data.write(to: fileURL, options: .atomic)
    }
}
