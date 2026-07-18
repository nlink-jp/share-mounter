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

    init(store: ShareStore, credentials: CredentialStore, mounter: Mounter, inventory: MountInventory) {
        self.store = store
        self.credentials = credentials
        self.mounter = mounter
        self.inventory = inventory
        reload()
    }

    var shares: [Share] { statuses.map(\.share) }

    /// Re-read the share list and recompute each share's state from the OS mount
    /// table (so already-mounted shares show as mounted at launch).
    func reload() {
        let shares = store.load()
        let mounts = inventory.currentMounts()
        statuses = shares.map { share in
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

    func setPassword(_ password: String, for share: Share) {
        credentials.setPassword(password, for: share.credentialKey)
    }

    /// Shares flagged for auto-mount (login / network-recovery driven in Phase 2).
    func autoMountShares() -> [Share] { shares.filter(\.autoMount) }

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
