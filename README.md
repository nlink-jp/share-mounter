# share-mounter

A macOS menu-bar app that auto-mounts SMB file-server shares at login —
**without opening a Finder window**.

The usual "mount once, make an alias, add it to Login Items" trick pops a Finder
window open on every login. share-mounter mounts through the **NetFS framework**
instead, so no window appears, and the share shows up in the Finder sidebar as a
normal network volume. Register several shares, flag the ones you want mounted at
login, and toggle any of them mount/unmount straight from the menu bar.

- **No Finder window** — NetFS mounts the volume without asking Finder to reveal it.
- **Sidebar volume** — placed under `/Volumes`, so it appears as a network volume.
- **Multiple shares** — register a list; mount/unmount each from the menu bar.
- **Auto-mount at login** — per-share toggle.
- **Keychain credentials** — passwords are stored in the Keychain, never on disk.

> **Apple Silicon, macOS 13 (Ventura) or later.** SMB only.

## Install

```sh
brew install nlink-jp/tap/share-mounter
```

Or download `ShareMounter.app` from the [latest release](https://github.com/nlink-jp/share-mounter/releases)
(Developer ID signed + notarized, Apple Silicon).

## Status

v0.1.0 — initial release. See the RFP for design background:
[docs/en/share-mounter-rfp.md](docs/en/share-mounter-rfp.md).

## Build

```sh
make build       # swift build -c release
make test        # swift test
make run         # swift run (debug)
make build-app   # assemble + Developer-ID sign dist/ShareMounter.app
make package     # notarize + staple + zip the release asset
```

`build-app` generates `AppIcon.icns` from `assets/AppIcon-1024.png` (regenerate
that source with `swift assets/make-appicon.swift`). The app is `LSUIElement`
(menu bar, no Dock icon); the version comes from `git describe`.

## How it works

| Concern            | Mechanism                                                        |
| ------------------ | --------------------------------------------------------------- |
| Mount (no window)  | `NetFSMountURLSync` with `UIOption = NoUI`, `mountpath = nil`    |
| Unmount            | `unmount(2)` (force-retry on a busy volume)                     |
| Already-mounted?   | `getmntinfo(3)` + share matching (`MountMatcher`)               |
| Credentials        | Keychain generic-password items (`CredentialStore`)            |
| Network-not-up-yet | port-445 probe + exponential backoff (`ReachabilityWaiter`)    |

## License

MIT — see [LICENSE](LICENSE).
