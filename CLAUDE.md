# CLAUDE.md — share-mounter

Organization rules: https://github.com/nlink-jp/.github/blob/main/CONVENTIONS.md
Workspace rules also apply (see the parent `nlink-jp/CLAUDE.md`).

## What this is

macOS menu-bar SwiftUI app that auto-mounts SMB shares at login **without
opening a Finder window**, via the NetFS framework. Sidebar network volume,
Keychain auth, per-share auto-mount toggle, manual mount/unmount from the menu.
**Apple Silicon, macOS 13+. SMB only. GUI only.**

## Project rules

- **Always `make build-app`** for distribution — never ship an unsigned bundle.
- **Tests required** — `make test` / `swift test` must pass before committing.
- **No secrets on disk** — passwords go to the Keychain via `CredentialStore`;
  never in `ShareStore` JSON, UserDefaults, or `@AppStorage`.
- **`LSUIElement = true`** — menu-bar app; flip activation policy to `.regular`
  only while a window (Settings) is visible, back to `.accessory` when it closes.
- **NetFS is load-bearing** — mount via `NetFSMountURLSync` (`UIOption = NoUI`,
  `mountpath = nil`). Do not fall back to `open smb://…` or Finder (they open a
  window) or embed credentials in the URL (they leak into `ps`).
- **macOS 13 minimum** — `SMAppService` requires it; do not use macOS 14+-only
  APIs (e.g. `SettingsLink`) without a 13 fallback.
- **Keep OS access behind protocols** (`Mounter`, `MountInventory`,
  `CredentialStore`, `PortProbe`) so the logic stays unit-testable.

## Series

Part of **util-series** (submodule). Repo: `github.com/nlink-jp/share-mounter`.
