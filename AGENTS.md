# AGENTS.md — share-mounter

## What it is

macOS menu-bar app (SwiftUI) that auto-mounts SMB shares at login **without
opening a Finder window**, and lets you mount/unmount registered shares from the
menu bar. Mounts via the **NetFS framework** (window-less, lands under `/Volumes`
as a sidebar network volume, native Keychain auth). **Apple Silicon, macOS 13+.
SMB only. GUI only** (no CLI — a deliberate departure from the util-series
CLI-in-GUI convention; testability is covered by engine-layer unit tests).

## Build / test / run

```sh
make build      # swift build -c release
make test       # swift test
make run        # swift run (debug)
make build-app  # assemble + Developer-ID sign dist/ShareMounter.app
make package    # notarize + staple + zip the release asset
make brew       # generate the Homebrew cask into ../homebrew-tap
```

`build-app` renders `AppIcon.icns` from `assets/AppIcon-1024.png` (regenerate:
`swift assets/make-appicon.swift`). `LSUIElement` app; version from `git describe`.

## Layout

```
Sources/ShareMounter/
  App.swift                     @main; MenuBarExtra + Settings scene + AppDelegate
  AppModel.swift                @MainActor orchestrator; per-share MountState
  Models/
    Share.swift                 config model (no secrets); smb URL + credentialKey
    ShareStore.swift            JSON persistence under Application Support
  Services/
    CredentialStore.swift       Keychain + in-memory stores (protocol)
    Mounter.swift               Mounter/MountInventory protocols + MountMatcher (pure)
    NetFSMounter.swift          NetFSMountURLSync (NoUI, /Volumes) + unmount(2)
    SMBMountInventory.swift      getmntinfo → mounted volumes
    Reachability.swift          PortProbe + Backoff + ReachabilityWaiter
    LoginItemManager.swift      SMAppService launch-at-login (protocol + fake)
    NetworkMonitor.swift        NWPathMonitor rising-edge → re-mount callback
  Views/
    MenuContentView.swift       menu: share rows (toggle) + settings/quit
    SettingsView.swift          register/edit shares; password → Keychain
Tests/ShareMounterTests/        Share, ShareStore, MountMatcher, Backoff,
                                ReachabilityWaiter, CredentialStore, AppModel
                                (+ Fakes.swift doubles)
```

## Design invariants / gotchas

- **NetFS is why there's no window.** `open smb://…` and Finder "Connect to
  Server" ask Finder to reveal the volume (window). `NetFSMountURLSync` with
  `mountpath = nil` mounts under `/Volumes` (sidebar volume) and `UIOption = NoUI`
  suppresses the auth dialog — so login-time mounts are fully headless.
- **No secrets on disk.** Passwords live only in the Keychain (`CredentialStore`);
  `Share`/`ShareStore` JSON has no password field (a test pins this).
- **NetFS option keys are literal strings** ("UIOption"/"NoUI"/"Guest") from
  `<NetFS/NetFS.h>` — the CFSTR macros don't reliably import into Swift.
- **`statfs` name collision:** the type is shadowed by the `statfs()` function in
  Swift, so the inventory uses `getmntinfo` (no `statfs()` construction).
- **All OS access is behind protocols** (`Mounter`, `MountInventory`,
  `CredentialStore`, `PortProbe`) so `AppModel` and the matcher/backoff logic are
  unit-tested with doubles; NetFS/getmntinfo/NWConnection impls run on real HW.
- **`MountMatcher` is pure** and handles `//host/share`, `//user@host/share`,
  `//DOMAIN;user@host/share`, sub-paths, and percent-encoding, case-insensitively.

## Status

Phase 1 + Phase 2 code complete: `swift build` clean, `swift test` green
(43 tests). Wired: `SMAppService` launch-at-login (Settings toggle),
reachability-gated `autoMountAll()` at launch, and re-mount on `NWPathMonitor`
recovery / wake-from-sleep. Icon present (`assets/AppIcon-1024.png`).

**Not yet done — on-device E2E:** the "mounts a real SMB share with no Finder
window, shows in the sidebar, survives sleep/VPN" check needs a live SMB server
and must be run on real hardware (per RFP Phase 2 review). **Phase 3:** release
(notarize, Homebrew tap, submodule, profile, check-org).
