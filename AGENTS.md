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
make verify-release  # gate: .notarized marker + stapler validate (run before upload)
make brew       # generate the Homebrew cask into ../homebrew-tap
```

`build-app` renders `AppIcon.icns` from `assets/AppIcon-1024.png` (regenerate:
`swift assets/make-appicon.swift`). `LSUIElement` app; version from `git describe`.

## Layout

```
Sources/ShareMounter/
  Entry.swift                   @main; single-instance guard, then ShareMounterApp.main()
  SingleInstance.swift          singleInstanceDecision() — startup duplicate-
                                instance guard (pure; pids in, decision out)
  App.swift                     MenuBarExtra + Settings scene + AppDelegate
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
    MenuContentView.swift       menu: per-share submenu (Mount/Unmount/Reveal),
                                About, version line, settings/quit
    SettingsView.swift          NavigationSplitView; drag-reorder, live-apply
                                (no Save), password → Keychain on Return/blur
Tests/ShareMounterTests/        Share, ShareStore, MountMatcher, Backoff,
                                ReachabilityWaiter, CredentialStore, AppModel,
                                SingleInstance (+ Fakes.swift doubles)
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
- **Never put a bottom `safeAreaInset` on the `NavigationSplitView`** in
  `SettingsView`. The inset shortens the split view's own frame but *not* the
  sidebar column, which keeps drawing full-window-height — so the sidebar's
  bottom bar (the +/− buttons) lands in the same band as the footer and is
  painted over by it (v0.1.1 shipped with the buttons invisible). The footer
  must stay a `VStack` sibling. The sidebar's own `.safeAreaInset` bar is fine.
  Layout regressions like this are not unit-testable here; verify by building
  the app and opening Settings.
- **`MountMatcher` is pure** and handles `//host/share`, `//user@host/share`,
  `//DOMAIN;user@host/share`, sub-paths, and percent-encoding, case-insensitively.
- **Notification clicks launch by bundle ID — enforce a single instance.**
  Clicking a banner makes notificationd open the app via LaunchServices,
  which resolves `jp.nlink.share-mounter` among *all* registered
  copies (`dist/` dev builds, release-verification extractions,
  `/Applications`) and may start a different copy than the running one →
  two menu bar items, double auto-mount attempts. Guarded at two layers:
  `LSMultipleInstancesProhibited` (Info.plist, stops LaunchServices
  launches) and a startup check in `Entry.main`
  (`singleInstanceDecision`, pure + tested) that exits with a stderr note
  (covers direct exec / `open -n`). Side effect: to run a `dist/` build,
  quit the installed instance first — a second copy now refuses to start.

## Status

Released (public, Developer ID signed + notarized, Homebrew tap, util-series
submodule, check-org green). On-device E2E done against a real SMB server: no
Finder window on mount, sidebar volume, config JSON carries no password.
`swift test` green. Icon present (`assets/AppIcon-1024.png`).
