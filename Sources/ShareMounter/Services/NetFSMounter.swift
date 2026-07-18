import Darwin
import Foundation
import NetFS

/// Mounts SMB shares via the NetFS framework.
///
/// Why NetFS (not `open smb://…` or `mount_smbfs`):
///   - It mounts without asking Finder to reveal the volume, so **no Finder
///     window opens**.
///   - With `mountpath == nil` the volume is placed under `/Volumes` (via
///     `automountd`, no privilege juggling), so it shows in the Finder sidebar
///     as a normal network volume.
///   - The auth UI is suppressed (`UIOption = NoUI`) so a login-time / headless
///     mount never pops a dialog; missing/bad credentials return an error.
final class NetFSMounter: Mounter {
    // CFSTR key/value strings from <NetFS/NetFS.h>, used literally so the code
    // does not depend on those C macros being imported into Swift.
    private enum Key {
        static let uiOption = "UIOption"
        static let useGuest = "Guest"
    }
    private enum UIOptionValue {
        static let noUI = "NoUI"
    }

    func mount(_ request: MountRequest) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cfURL = CFURLCreateWithString(nil, request.url as CFString, nil) else {
                    continuation.resume(throwing: MountError.invalidURL)
                    return
                }

                let openOptions = NSMutableDictionary()
                openOptions[Key.uiOption] = UIOptionValue.noUI
                if request.guest { openOptions[Key.useGuest] = true }

                let mountOptions = NSMutableDictionary()
                var mountpoints: Unmanaged<CFArray>?

                let user = request.guest ? nil : request.username
                let passwd = request.guest ? nil : request.password

                let status = NetFSMountURLSync(
                    cfURL,
                    nil,
                    user as CFString?,
                    passwd as CFString?,
                    openOptions as CFMutableDictionary,
                    mountOptions as CFMutableDictionary,
                    &mountpoints
                )

                guard status == 0 else {
                    continuation.resume(
                        throwing: MountError.failed(code: status, message: MountError.describe(status)))
                    return
                }

                let paths = (mountpoints?.takeRetainedValue() as NSArray?) as? [String]
                continuation.resume(returning: paths?.first ?? "")
            }
        }
    }

    func unmount(path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                if Darwin.unmount(path, 0) == 0 {
                    continuation.resume()
                    return
                }
                // A busy volume: retry with force.
                if Darwin.unmount(path, MNT_FORCE) == 0 {
                    continuation.resume()
                    return
                }
                let e = errno
                continuation.resume(
                    throwing: MountError.failed(code: e, message: String(cString: strerror(e))))
            }
        }
    }
}
