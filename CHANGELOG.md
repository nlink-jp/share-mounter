# Changelog

All notable changes to share-mounter are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Project scaffold: Swift Package (SwiftUI menu-bar app), Makefile with
  Developer-ID sign / notarize / Homebrew-cask pipeline, docs, MIT license.
- App icon (`assets/AppIcon-1024.png`) and a reproducible generator
  (`assets/make-appicon.swift`).
- Phase 1 core (unit-tested):
  - `Share` model + JSON persistence (`ShareStore`); no secrets on disk.
  - `CredentialStore` (Keychain-backed + in-memory double).
  - `Mounter` abstraction with `NetFSMounter` (window-less SMB mount via NetFS,
    `unmount(2)` eject) and `MountMatcher` for already-mounted detection.
  - `SMBMountInventory` (`getmntinfo`) for the OS mount table.
  - `ReachabilityWaiter` (port-445 probe + exponential `Backoff`) for the
    network-not-up-yet-at-login case.
  - `AppModel` orchestrator with a basic menu-bar UI and settings window.
- Phase 2 (OS integration):
  - `LoginItemManager` (`SMAppService`) + "Launch at login" toggle in Settings.
  - `AppModel.autoMountAll()` — reachability-gated auto-mount of flagged shares,
    skipping already-mounted ones; re-entrant calls are coalesced.
  - `NetworkMonitor` (`NWPathMonitor`) + wake-from-sleep observer → re-mount on
    network recovery and after sleep, so shares stay mounted across VPN
    reconnects and wake.

### Changed
- Settings open in a dedicated window (reliable across macOS versions) rather
  than via the private `showSettingsWindow:` selector.
- Settings form is left-aligned with full-width fields and labels above.
- Password field shows whether a credential is stored in the Keychain
  (saved / will-save-on-Save / none), so the save state is unambiguous.

### Fixed
- Menu no longer drifts from reality when a volume is ejected from Finder:
  `NSWorkspace` mount/unmount/rename observers refresh state from the OS.

[Unreleased]: https://github.com/nlink-jp/share-mounter
