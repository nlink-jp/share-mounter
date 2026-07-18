import Foundation

/// Mount state of a single share, as shown in the menu.
enum MountState: Equatable {
    case unmounted
    case mounting
    case mounted(path: String)
    case unmounting
    case error(String)
}

/// A share plus its current mount state.
struct ShareStatus: Identifiable, Equatable {
    let share: Share
    var state: MountState
    var id: UUID { share.id }
}

/// Ties the store, credential store, mounter, and mount inventory together and
/// exposes observable per-share status to the UI. All OS access is behind
/// injected protocols so this type is testable with doubles.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var statuses: [ShareStatus] = []

    private let store: ShareStore
    private let credentials: CredentialStore
    private let mounter: Mounter
    private let inventory: MountInventory
    private let reachability: ReachabilityWaiter
    private let loginItems: LoginItemManaging
    private var isAutoMounting = false

    init(store: ShareStore,
         credentials: CredentialStore,
         mounter: Mounter,
         inventory: MountInventory,
         reachability: ReachabilityWaiter = ReachabilityWaiter(probe: NWPortProbe()),
         loginItems: LoginItemManaging = LoginItemManager()) {
        self.store = store
        self.credentials = credentials
        self.mounter = mounter
        self.inventory = inventory
        self.reachability = reachability
        self.loginItems = loginItems
        reload()
    }

    var shares: [Share] { statuses.map(\.share) }

    /// Re-read the share list and recompute each share's state from the OS mount
    /// table. Called at launch and whenever a volume mounts/unmounts (including
    /// an external unmount from Finder), so the menu never drifts from reality.
    func reload() {
        let shares = store.load()
        let mounts = inventory.currentMounts()
        let previous = Dictionary(statuses.map { ($0.id, $0.state) }, uniquingKeysWith: { first, _ in first })
        statuses = shares.map { share in
            // Preserve an in-flight operation so a concurrent volume event (or a
            // settings save) doesn't clobber a mount/unmount that's underway.
            if let prev = previous[share.id], prev == .mounting || prev == .unmounting {
                return ShareStatus(share: share, state: prev)
            }
            if let path = MountMatcher.mountPath(for: share, in: mounts) {
                return ShareStatus(share: share, state: .mounted(path: path))
            }
            return ShareStatus(share: share, state: .unmounted)
        }
    }

    /// Persist an edited share list, then refresh state.
    func saveShares(_ shares: [Share]) {
        try? store.save(shares)
        reload()
    }

    /// Persist edited share metadata/order and reflect it in the menu without
    /// re-probing the OS mount table — each existing share keeps its current
    /// state, and new shares start unmounted. Used for live-apply edits.
    func updateShares(_ shares: [Share]) {
        try? store.save(shares)
        let previous = Dictionary(statuses.map { ($0.id, $0.state) }, uniquingKeysWith: { first, _ in first })
        statuses = shares.map { ShareStatus(share: $0, state: previous[$0.id] ?? .unmounted) }
    }

    func setPassword(_ password: String, for share: Share) {
        credentials.setPassword(password, for: share.credentialKey)
    }

    func removePassword(for share: Share) {
        credentials.removePassword(for: share.credentialKey)
    }

    /// Whether a non-empty password is stored in the Keychain for this share.
    func hasStoredPassword(for share: Share) -> Bool {
        !(credentials.password(for: share.credentialKey) ?? "").isEmpty
    }

    /// Shares flagged for auto-mount (driven at login / on network recovery).
    func autoMountShares() -> [Share] { shares.filter(\.autoMount) }

    // MARK: - Login item

    var isLoginItemEnabled: Bool { loginItems.isEnabled }

    func setLoginItem(_ enabled: Bool) {
        try? loginItems.setEnabled(enabled)
    }

    // MARK: - Auto-mount

    /// Mount every auto-mount share that isn't already mounted, each gated on the
    /// server becoming reachable first (so a login-time / post-wake attempt
    /// doesn't fail merely because the network/VPN isn't up yet). Re-entrant
    /// calls (launch + network-recovery firing together) are coalesced.
    func autoMountAll() async {
        guard !isAutoMounting else { return }
        isAutoMounting = true
        defer { isAutoMounting = false }

        for share in autoMountShares() {
            if case .mounted = state(of: share.id) { continue }
            setState(share.id, .mounting)
            let reachable = await reachability.waitUntilReachable(host: share.host)
            guard reachable else {
                setState(share.id, .error("Server unreachable"))
                continue
            }
            if case .mounted = state(of: share.id) { continue }
            await performMount(share)
        }
    }

    // MARK: - Actions

    func toggle(_ share: Share) {
        if case .mounted = state(of: share.id) {
            unmount(share)
        } else {
            mount(share)
        }
    }

    func mount(_ share: Share) {
        Task { await performMount(share) }
    }

    func unmount(_ share: Share) {
        Task { await performUnmount(share) }
    }

    /// Awaitable mount used by both the UI and tests.
    func performMount(_ share: Share) async {
        setState(share.id, .mounting)
        let request = MountRequest(
            url: share.smbURLString,
            username: share.username.isEmpty ? nil : share.username,
            password: share.isGuest ? nil : credentials.password(for: share.credentialKey),
            guest: share.isGuest)
        do {
            let path = try await mounter.mount(request)
            setState(share.id, .mounted(path: path))
        } catch {
            setState(share.id, .error(Self.message(for: error)))
        }
    }

    /// Awaitable unmount used by both the UI and tests.
    func performUnmount(_ share: Share) async {
        guard case .mounted(let path) = state(of: share.id) else { return }
        setState(share.id, .unmounting)
        do {
            try await mounter.unmount(path: path)
            setState(share.id, .unmounted)
        } catch {
            setState(share.id, .error(Self.message(for: error)))
        }
    }

    // MARK: - Helpers

    func state(of id: UUID) -> MountState {
        statuses.first(where: { $0.id == id })?.state ?? .unmounted
    }

    private func setState(_ id: UUID, _ newState: MountState) {
        guard let index = statuses.firstIndex(where: { $0.id == id }) else { return }
        statuses[index].state = newState
    }

    static func message(for error: Error) -> String {
        if let mountError = error as? MountError {
            switch mountError {
            case .invalidURL: return "Invalid SMB URL"
            case .failed(_, let message): return message
            }
        }
        return error.localizedDescription
    }
}
