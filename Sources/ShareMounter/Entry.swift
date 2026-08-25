import AppKit
import SwiftUI

@main
@MainActor
enum Main {
    static func main() {
        // Two instances would stack two menu bar items and double the
        // auto-mount attempts. LSMultipleInstancesProhibited (Info.plist)
        // stops LaunchServices launches; this guard stops the rest (direct
        // exec, `open -n`). It runs before ShareMounterApp so a duplicate
        // exits without ever constructing the model or auto-mounting.
        let bundleID = Bundle.main.bundleIdentifier
        let instancePIDs = bundleID.map { id in
            NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .map(\.processIdentifier)
        } ?? []
        if case .exitDuplicate(let message) = singleInstanceDecision(
            bundleID: bundleID,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            instancePIDs: instancePIDs
        ) {
            FileHandle.standardError.write(Data((message + "\n").utf8))
            exit(0)
        }
        ShareMounterApp.main()
    }
}
