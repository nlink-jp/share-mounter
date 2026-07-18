# share-mounter

SMB ファイルサーバの共有をログイン時に自動マウントする macOS メニューバーアプリ。
**Finder ウィンドウを一切開きません。**

「一度マウントして alias を作り、起動項目に登録する」定番の方法では、ログインの
たびに Finder ウィンドウが勝手に開いてしまいます。share-mounter は **NetFS
framework** 経由でマウントするため、ウィンドウが出ず、共有は Finder サイドバーに
通常のネットワークボリュームとして表示されます。複数の共有を登録し、ログイン時に
マウントするものを選び、メニューバーから各共有を随時 mount/unmount できます。

- **ウィンドウを開かない** — NetFS は Finder に表示を依頼せずボリュームをマウント。
- **サイドバーにボリューム** — `/Volumes` に配置され、ネットワークボリュームとして表示。
- **複数共有** — リスト登録し、メニューバーから各共有を mount/unmount。
- **ログイン時に自動マウント** — 共有ごとのトグル。
- **Keychain 認証** — パスワードは Keychain に保存し、ディスクには置かない。

> **Apple Silicon・macOS 13 (Ventura) 以降。** SMB 専用。

## インストール

```sh
brew install nlink-jp/tap/share-mounter
```

または [最新リリース](https://github.com/nlink-jp/share-mounter/releases) から
`ShareMounter.app` をダウンロード（Developer ID 署名 + notarize 済み、Apple Silicon）。

## ステータス

v0.1.0 — 初回リリース。設計の背景は RFP を参照：
[docs/ja/share-mounter-rfp.ja.md](docs/ja/share-mounter-rfp.ja.md)。

## ビルド

```sh
make build       # swift build -c release
make test        # swift test
make run         # swift run (デバッグ)
make build-app   # dist/ShareMounter.app を組み立て Developer ID 署名
make package     # notarize + staple + zip
```

`build-app` は `assets/AppIcon-1024.png` から `AppIcon.icns` を生成します
（このソース画像は `swift assets/make-appicon.swift` で再生成）。アプリは
`LSUIElement`（メニューバー常駐・Dock アイコンなし）。バージョンは `git describe`
から取得します。

## 仕組み

| 関心事                   | 手段                                                           |
| ------------------------ | ------------------------------------------------------------- |
| マウント（ウィンドウ無し）| `NetFSMountURLSync`（`UIOption = NoUI`, `mountpath = nil`）    |
| アンマウント             | `unmount(2)`（ビジー時は force で再試行）                       |
| マウント済み判定         | `getmntinfo(3)` ＋ 共有の突き合わせ（`MountMatcher`）           |
| 認証情報                 | Keychain の generic-password（`CredentialStore`）             |
| ネットワーク未確立対策   | 445 番ポート到達確認 ＋ 指数バックオフ（`ReachabilityWaiter`） |

## ライセンス

MIT — [LICENSE](LICENSE) を参照。
