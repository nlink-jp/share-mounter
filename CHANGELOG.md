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

[Unreleased]: https://github.com/nlink-jp/share-mounter
