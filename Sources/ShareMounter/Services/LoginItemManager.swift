import Foundation
import ServiceManagement

/// Manages "launch at login" for the app itself via the modern
/// ServiceManagement API (`SMAppService`, macOS 13+). Registration surfaces in
/// System Settings › General › Login Items, where the user can also revoke it.
protocol LoginItemManaging: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

final class LoginItemManager: LoginItemManaging {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}

/// In-memory login-item double for tests.
final class InMemoryLoginItems: LoginItemManaging {
    private(set) var isEnabled: Bool
    var failNext: Error?
    init(enabled: Bool = false) { isEnabled = enabled }
    func setEnabled(_ enabled: Bool) throws {
        if let error = failNext { failNext = nil; throw error }
        isEnabled = enabled
    }
}
