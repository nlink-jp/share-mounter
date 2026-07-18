# Changelog

All notable changes to share-mounter are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-07-18

Initial release.

### Added
- Menu-bar app that mounts SMB shares via the **NetFS framework** — no Finder
  window opens, and the share appears in the Finder sidebar as a network volume
  under `/Volumes`.
- Register multiple shares; mount / unmount each from the menu bar.
- Per-share **auto-mount at login** (`SMAppService` launch-at-login), with a
  toggle in Settings.
- Reachability-gated auto-mount — waits for the server on port 445 (exponential
  backoff) before mounting, and re-mounts on network recovery and after wake
  from sleep, so shares survive VPN reconnects and sleep.
- Passwords are stored in the **Keychain** (never on disk); the settings panel
  shows whether a credential is saved.
- The menu stays in sync when a volume is ejected from Finder.
- Apple Silicon, macOS 13 (Ventura) or later. SMB only. GUI only.

[0.1.0]: https://github.com/nlink-jp/share-mounter/releases/tag/v0.1.0
