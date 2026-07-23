# Changelog

All notable changes to share-mounter are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.2] - 2026-07-23

### Fixed
- The **+ / −** buttons for adding and removing shares were invisible in
  Settings. The footer ("Launch at login" / version) was attached to the
  `NavigationSplitView` as a bottom `safeAreaInset`, which does not shorten the
  sidebar column — the sidebar kept drawing full-height and its button bar ended
  up underneath the footer. The footer is now a sibling in a `VStack`.

[0.1.2]: https://github.com/nlink-jp/share-mounter/releases/tag/v0.1.2

## [0.1.1] - 2026-07-19

### Added
- Each share in the menu bar is now a submenu with explicit **Mount / Unmount /
  Reveal in Finder** actions, so a share can't be unmounted by an accidental
  single click.
- The app version is shown directly in the menu and in the Settings footer, and
  an **About ShareMounter** item opens the standard About panel from the menu.
- **Drag to reorder** shares in Settings; the menu reflects the new order.

### Changed
- Settings **apply live** (macOS-style) — the Save button is gone. The password
  is committed to the Keychain on Return or when its field loses focus.
- Settings uses a standard `NavigationSplitView` window: proper title bar and a
  larger default size so the detail pane no longer shows a scrollbar by default.

[0.1.1]: https://github.com/nlink-jp/share-mounter/releases/tag/v0.1.1

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
