# RFP: share-mounter

> Generated: 2026-07-18
> Status: Draft

## 1. Problem Statement

**share-mounter** is a menu-bar-resident macOS GUI app that automatically mounts a specified SMB file-server share at login. The traditional approach — mount once, make an alias, and add it to Login Items — pops open a Finder window on every login, which is a poor experience. Because share-mounter mounts via the NetFS framework, it **never opens a Finder window** and surfaces the share in the Finder sidebar as an ordinary network volume. It also follows through the common real-world hiccups automatically: the network not being up right after login, waking from sleep, and reconnecting a VPN — keeping the share continuously mounted. In addition, users can register multiple shares in a list and manually mount / unmount any volume from the menu bar. The target user is a solo macOS user who works daily with an in-house SMB file server (including the operator themselves). The deliverable is signed + notarized and is intended for distribution via a Homebrew tap.

## 2. Functional Specification

### Commands / API Surface

The app is **GUI-only** (no CLI subcommands). There are two operational surfaces.

**Menu bar (primary surface)**
- Icon reflects overall status (active if at least one share is mounted / warning on error)
- Clicking shows a dropdown **list of registered shares**. Each row shows:
  - Display name + mount status (✓ mounted / not mounted / error)
  - Clicking **toggles** (not mounted → mount / mounted → unmount(eject))
- Below the list: "Add share…", "Settings…", "Quit share-mounter"

**Settings window (register / edit shares)**
- Per share: display name / server (`smb://host` or `host`) / share name / username / **auto-mount at login** toggle / guest connection option
- Passwords are stored in the Keychain (never in the config file)
- Add / edit / delete / reorder shares

### Input / Output

- **Input**: share details registered by the user via the GUI (server, share name, credentials). No external or piped input is accepted.
- **Output (side effects)**: NetFS-driven volume mount / unmount. The mount target is `/Volumes/<share-name>` (NetFS default), which appears in the Finder sidebar under "Locations" as a network volume. No Finder window opens.

### Configuration

- Share metadata = JSON under Application Support (display name, server, share name, username, auto-mount flag, guest flag, ordering, etc. — **no secrets**)
- Passwords = Keychain (internet password)
- Launch-at-login enabled/disabled = `SMAppService` registration state (tied to System Settings › Login Items)

### External Dependencies

- **No** external APIs / OAuth / cloud services whatsoever
- OS frameworks: NetFS (mounting), Security / Keychain Services (credentials), ServiceManagement (`SMAppService`: launch at login), Network (`NWPathMonitor`: network monitoring), AppKit / SwiftUI (UI)
- SMB dialect and authentication negotiation are delegated to the OS SMB stack

## 3. Design Decisions

**Language / framework: Swift / SwiftUI (+ AppKit)**
- NetFS is a C framework; calling it from Swift/ObjC is the most natural path
- `SMAppService` (launch at login), `NWPathMonitor` (network monitoring), Keychain Services, and wake-from-sleep notifications are all native OS APIs
- Implementation patterns align with the existing Swift menu-bar apps (claude-usage-lens-gui / active-lens-gui / quick-translate)
- The menu bar is built with `MenuBarExtra` (SwiftUI) by default. If a continuously animated icon is ever needed, switch to AppKit `NSStatusItem` (known caveat)

**Target platform: darwin / Apple Silicon only, macOS 13 (Ventura) or later**
- NetFS and `SMAppService` are macOS-specific; same policy as the existing Swift GUIs
- `SMAppService` (modern login-item registration) requires macOS 13+, so 13 is the floor

**GUI-only (no CLI subcommands)**
- A deliberate departure from the util-series convention of co-hosting CLI subcommands in GUI apps
- Rationale: the app depends heavily on NetFS / Keychain, so a standalone CLI adds little value. Testability is covered by unit tests on the mount-engine layer

**Relationship to existing tools**
- Sits alongside the util-series GUI apps. This is the first "system-integration / network-volume" utility, so there is no functional overlap

**Explicitly out of scope**
- Protocols other than SMB (AFP / NFS / WebDAV / FTP)
- CLI subcommands (GUI only)
- Non-macOS / Intel-only builds (Apple Silicon assumed; no universal build)
- Managing across multiple macOS user accounts (single login session, single user assumed)
- Mounting arbitrary URLs from external input (only registered shares are targeted, narrowing the injection surface)

## 4. Development Plan

### Phase 1: Core (mount engine + tests)
- NetFS wrapper (`NetFSMountURLSync`/Async mount / unmount, mount-state query)
- Keychain integration (store / retrieve / delete internet password)
- Share config model and persistence (JSON under Application Support, no secrets)
- Unit tests: config serialization / restore, state determination, port-445 reachability logic (NetFS calls behind a mock boundary)
- Independently reviewable without UI

### Phase 2: Features (menu bar UI + OS integration)
- `MenuBarExtra` menu: list of registered shares + status + toggle mount/unmount
- Settings window: add / edit / delete / reorder shares, auto-mount toggle, Keychain storage
- Launch at login via `SMAppService`, auto-mount on startup
- Re-mount via `NWPathMonitor` + wake-from-sleep notifications, with backoff waiting on port-445 reachability
- Independently reviewable on real hardware (including verifying no window opens and the sidebar volume appears)

### Phase 3: Release (docs + icon + signing/notarization + distribution)
- **Create the app icon** (.icns, full resolution set; includes a template icon for the menu bar)
- README.md / README.ja.md, CHANGELOG.md, AGENTS.md
- Developer ID signing + notarization (verify the .app with ditto / spctl)
- Homebrew tap (prebuilt-binary approach; do not build from source, to preserve the signature)
- Add submodule, update org profile, sync web-site catalog (EN/JA), confirm `check-org.sh` is green

**Independent review units**: Phase 1 (engine + tests) / Phase 2 (UI + OS integration) / Phase 3 (full release).

## 5. Required API Scopes / Permissions

- **External services: None** (no OAuth / external APIs; SMB credentials are registered by the user)
- **macOS permissions**:
  - No special TCC grant needed (mounting a network volume does not require Full Disk Access, etc.)
  - Keychain: read/write only the app's own internet passwords
  - Launch at login: user approval in System Settings › Login Items when registering `SMAppService` (first run only)
  - **Non-sandboxed** Developer ID distribution (signed with Hardened Runtime enabled, then notarized)

## 6. Series Placement

Series: util-series

Reason: util-series contains not only CLIs but also GUI apps (csv-editor / claude-usage-lens-gui / active-lens-gui / quick-translate, etc.). share-mounter is a "macOS utility that supports local operations" and fits this grouping. It does not match the cybersecurity / lite / chatops themes.

## 7. External Platform Constraints

- **Network dependency**: reachability of the SMB server (may require VPN). It may not be up right after login → absorbed by waiting on port-445 reachability with backoff
- **NetFS behavior**: mount target is `/Volumes/<share-name>`. If a same-named volume already exists, macOS appends a suffix automatically (`-1`, etc.)
- **macOS 13+ required** (`SMAppService`)
- **SMB dialect / auth** delegated to the OS SMB stack (the app only drives it via NetFS)
- **Rate limits: none** (no external API dependency)
- **Distribution**: Gatekeeper / notarization required. Login-item registration needs user approval on first run
- **UI constraint**: `MenuBarExtra` is unsuited to continuous icon animation (switch to AppKit `NSStatusItem` if needed)

---

## Discussion Log

- **Starting problem**: the existing "mount, alias, add to Login Items" approach pops a Finder window open on every login — poor UX. The ask was to mount only, without opening a window.
- **Isolating why the window opens**: `open smb://…` and Finder's "Connect to Server" explicitly ask Finder to reveal the volume, opening a window. `mount_smbfs` / NetFS mount only, without opening a window. AppleScript `mount volume` was rejected because its behavior varies across macOS versions.
- **Choosing the mount foundation**: initially compared `mount_smbfs` (quick option) with NetFS (preferred). To satisfy "show as a network volume in the sidebar," **NetFS is best** — it auto-places under `/Volumes` via `automountd` (root) and integrates natively with the Keychain. `mount_smbfs` is disadvantaged because passwords can be exposed in `ps` and creating under `/Volumes` needs privileges.
- **Three requirements locked**: (1) SMB only, (2) show as a sidebar volume, (3) simple GUI operation. Confirmed these are simultaneously satisfied by NetFS + a Swift menu-bar app.
- **Feature expansion**: beyond auto-mount at login, added the requirement to register multiple shares in a list and **mount/unmount them by selecting from the menu bar** (a per-volume auto-mount on/off flag plus user-driven mount/unmount).
- **Decided GUI-only**: a departure from the util-series "co-host a CLI" convention, but recorded as deliberate because the heavy NetFS/Keychain dependency makes a standalone CLI low-value. Testability is covered by engine-layer unit tests.
- **Platform**: agreed on Apple Silicon only, macOS 13+ (`SMAppService` requirement).
- **Robustness core**: following through network-not-up-after-login, wake-from-sleep, and VPN reconnect — absorbed via port-445 reachability waiting + backoff, `NWPathMonitor`, and wake notifications. This is the core value of making it an app rather than a plain LaunchAgent plist.
- **Tool name**: compared with `mount-keeper` / `volume-keeper` / `auto-mounter`; chose **share-mounter** as the most straightforward description of the function.
- **Icon**: creating the app icon (.icns full resolution + a menu-bar template) is explicitly listed as a Phase 3 deliverable.
