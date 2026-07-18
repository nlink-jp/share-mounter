import Darwin
import Foundation

/// Enumerates currently-mounted SMB volumes via `getmntinfo(3)`.
final class SMBMountInventory: MountInventory {
    func currentMounts() -> [MountedVolume] {
        // getmntinfo fills a pointer to a static array of statfs — no allocation,
        // and it sidesteps the `statfs` type/function name collision in Swift.
        var raw: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&raw, MNT_NOWAIT)
        guard count > 0, let mounts = raw else { return [] }

        var result: [MountedVolume] = []
        for i in 0 ..< Int(count) {
            var fs = mounts[i]
            let from = Self.string(fromTuple: &fs.f_mntfromname)
            // SMB (and other network) mounts start with "//".
            guard from.hasPrefix("//") else { continue }
            let on = Self.string(fromTuple: &fs.f_mntonname)
            result.append(MountedVolume(from: from, path: on))
        }
        return result
    }

    /// Read a fixed-size C char array (imported as a tuple) into a String.
    private static func string<T>(fromTuple tuple: inout T) -> String {
        withUnsafePointer(to: &tuple) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
                String(cString: $0)
            }
        }
    }
}
