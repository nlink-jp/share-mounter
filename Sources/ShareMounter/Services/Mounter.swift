import Foundation

/// A single mount attempt's parameters. Credentials are passed here (not in the
/// URL) so they never appear in a process argument list.
struct MountRequest: Equatable {
    let url: String
    let username: String?
    let password: String?
    let guest: Bool
}

enum MountError: Error, Equatable {
    case invalidURL
    case failed(code: Int32, message: String)

    /// Human-readable hint for a NetFS status / errno value.
    static func describe(_ code: Int32) -> String {
        switch code {
        case 2:    return "Share or host not found"
        case 13:   return "Permission denied — check the username or password"
        case 60:   return "Timed out — the server may be unreachable"
        case 64:   return "Host is down"
        case 65:   return "No route to host"
        case -128: return "Cancelled"
        default:   return "Mount failed (code \(code))"
        }
    }
}

/// A volume currently mounted, as reported by the OS.
struct MountedVolume: Equatable {
    /// `f_mntfromname`, e.g. "//user@host/share".
    let from: String
    /// `f_mntonname`, e.g. "/Volumes/share".
    let path: String
}

/// Performs the actual mount/unmount. The production implementation is
/// `NetFSMounter`; tests use a double.
protocol Mounter {
    /// Mount the share; returns the resulting mount path (e.g. "/Volumes/share").
    func mount(_ request: MountRequest) async throws -> String
    /// Unmount the volume at the given path.
    func unmount(path: String) async throws
}

/// Enumerates volumes the OS currently has mounted.
protocol MountInventory {
    func currentMounts() -> [MountedVolume]
}

/// Pure matching between a configured `Share` and the OS mount table. Kept
/// separate from the OS calls so it is fully unit-testable.
enum MountMatcher {
    /// The mount path if `share` is currently mounted among `mounts`, else nil.
    static func mountPath(for share: Share, in mounts: [MountedVolume]) -> String? {
        mounts.first(where: { matches(share: share, from: $0.from) })?.path
    }

    /// Whether an OS mount-source string refers to this share. Handles
    /// "//host/share", "//user@host/share", "//DOMAIN;user@host/share", and
    /// percent-encoded variants. Host and share compare case-insensitively.
    static func matches(share: Share, from: String) -> Bool {
        let decoded = from.removingPercentEncoding ?? from
        guard decoded.hasPrefix("//") else { return false }
        let body = decoded.dropFirst(2)
        guard let slash = body.firstIndex(of: "/") else { return false }
        let authority = String(body[..<slash])
        let pathPart = String(body[body.index(after: slash)...])
        let host = authority.split(separator: "@").last.map(String.init) ?? authority
        let shareComp = pathPart.split(separator: "/").first.map(String.init) ?? pathPart
        guard !share.host.isEmpty, !share.shareName.isEmpty else { return false }
        return host.caseInsensitiveCompare(share.host) == .orderedSame
            && shareComp.caseInsensitiveCompare(share.shareName) == .orderedSame
    }
}
