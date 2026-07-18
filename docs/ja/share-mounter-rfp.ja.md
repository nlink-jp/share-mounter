# RFP: share-mounter

> Generated: 2026-07-18
> Status: Draft

## 1. Problem Statement

**share-mounter** は、指定した SMB ファイルサーバの共有を macOS のログイン時に自動でマウントするメニューバー常駐 GUI アプリである。従来の「一度マウントして alias を作り起動項目に登録する」方法では、ログインのたびに Finder ウィンドウが勝手に開いて UX が悪い。share-mounter は NetFS framework 経由でマウントするため **Finder ウィンドウを一切開かず**、共有を Finder サイドバーに通常のネットワークボリュームとして表示する。さらに、ログイン直後のネットワーク未確立・スリープ復帰・VPN 再接続にも自動追従し、常時マウントされた状態を維持する。加えて、複数の共有をリスト登録しておき、メニューバーから任意のボリュームを選んで手動で mount / unmount できる。ターゲットユーザーは、社内 SMB ファイルサーバを日常的に使う macOS 単独ユーザー（運用者自身の利用を含む）。成果物は署名 + notarize され、Homebrew tap での配布まで想定する。

## 2. Functional Specification

### Commands / API Surface

本アプリは **GUI 一本**（CLI サブコマンドは持たない）。操作面は次の2つ。

**メニューバー（主操作面）**
- アイコンで全体状態を表示（1つでもマウント中なら active 表示 / エラー時は警告表示）
- クリックで **登録済み共有のリスト**をドロップダウン表示。各行は:
  - 共有の表示名 ＋ マウント状態（✓ マウント中 / 未マウント / エラー）
  - クリックで **トグル動作**（未マウント→mount / マウント中→unmount(eject)）
- リスト下部に「共有を追加…」「設定…」「share-mounter を終了」

**設定ウィンドウ（共有の登録・編集）**
- 共有ごとに: 表示名 / サーバ（`smb://host` または `host`）/ 共有名 / ユーザー名 / **ログイン時に自動マウント** トグル / ゲスト接続オプション
- パスワードは Keychain に保存（設定ファイルには保持しない）
- 共有の追加・編集・削除・並べ替え

### Input / Output

- **入力**: ユーザーが GUI から登録する共有情報（サーバ、共有名、認証情報）。外部からの入力・パイプ入力は受け付けない。
- **出力（副作用）**: NetFS 経由のボリュームマウント／アンマウント。マウント先は `/Volumes/<共有名>`（NetFS 既定）で、Finder サイドバーの「場所」にネットワークボリュームとして表示される。Finder ウィンドウは開かない。

### Configuration

- 共有のメタ情報 = Application Support 下の JSON（表示名・サーバ・共有名・ユーザー名・auto-mount フラグ・ゲストフラグ・並び順など。**秘密情報は含めない**）
- パスワード = Keychain（internet password）
- ログイン起動の有効/無効 = `SMAppService` の登録状態（システム設定のログイン項目に連動）

### External Dependencies

- 外部 API / OAuth / クラウドサービスは **一切使わない**
- 依存する OS フレームワーク: NetFS（マウント）、Security / Keychain Services（認証情報）、ServiceManagement（`SMAppService`：ログイン起動）、Network（`NWPathMonitor`：ネットワーク監視）、AppKit / SwiftUI（UI）
- SMB 方言・認証ネゴシエーションは OS の SMB スタックに委譲する

## 3. Design Decisions

**言語・フレームワーク: Swift / SwiftUI（＋ AppKit）**
- NetFS は C の framework であり、Swift/ObjC から呼ぶのが最も素直
- `SMAppService`（ログイン起動）/ `NWPathMonitor`（ネットワーク監視）/ Keychain Services / スリープ復帰通知 がすべて OS ネイティブ API で完結する
- 既存の Swift メニューバー常駐アプリ群（claude-usage-lens-gui / active-lens-gui / quick-translate）と実装パターンが揃う
- メニューバー実装は `MenuBarExtra`（SwiftUI）を基本とする。アイコンを常時アニメーションさせる必要が出た場合は AppKit `NSStatusItem` に切り替える（既知の注意点）

**対象プラットフォーム: darwin / Apple Silicon 専用、macOS 13 (Ventura) 以上**
- NetFS・`SMAppService` は macOS 固有。既存 Swift GUI 群と同じ方針
- `SMAppService`（モダンなログイン項目登録）が macOS 13+ を要求するため、最低ラインを 13 とする

**GUI のみ（CLI サブコマンドなし）**
- util-series の「GUI に CLI サブコマンドを同居」規約からは意図的に逸脱する
- 理由: 本アプリは NetFS / Keychain 依存が強く CLI 単独の価値が薄い。テスト容易性はマウントエンジン層のユニットテストで担保する

**既存ツールとの関係**
- util-series の GUI 群と横並び。ただし「システム統合／ネットワークボリューム」系は本アプリが初で、機能的な重複はない

**明示的にスコープ外**
- SMB 以外のプロトコル（AFP / NFS / WebDAV / FTP）
- CLI サブコマンド（GUI 一本）
- 非 macOS / Intel 専用ビルド（Apple Silicon 前提。ユニバーサル化は任意で行わない）
- 複数 macOS ユーザーアカウントをまたいだ管理（ログインセッション単位・単独ユーザー前提）
- 外部入力から任意 URL をマウントする経路（登録済み共有のみを対象とし、インジェクション面を絞る）

## 4. Development Plan

### Phase 1: Core（マウントエンジン + テスト）
- NetFS ラッパ（`NetFSMountURLSync`/Async のマウント / アンマウント、マウント状態取得）
- Keychain 連携（internet password の保存・取得・削除）
- 共有設定モデルと永続化（Application Support の JSON、秘密情報なし）
- ユニットテスト: 設定の直列化 / 復元、状態判定、445 到達確認ロジック（NetFS 呼び出しはモック境界の背後に置く）
- UI なしで独立レビュー可能

### Phase 2: Features（メニューバー UI + OS 統合）
- `MenuBarExtra` によるメニュー: 登録済み共有リスト＋状態表示＋トグル mount/unmount
- 設定ウィンドウ: 共有の追加 / 編集 / 削除 / 並べ替え、auto-mount トグル、Keychain 保存
- `SMAppService` によるログイン起動、起動時の auto-mount 実行
- `NWPathMonitor` ＋ スリープ復帰通知による再マウント、445 到達待ちのバックオフ
- 実機で挙動を独立レビュー可能（ウィンドウ非表示・サイドバー表示の確認を含む）

### Phase 3: Release（ドキュメント + アイコン + 署名/notarize + 配布）
- **アプリアイコンの作成**（.icns、全解像度セット。メニューバー用テンプレートアイコン含む）
- README.md / README.ja.md、CHANGELOG.md、AGENTS.md
- Developer ID 署名 + notarize（.app を ditto / spctl で現物検証）
- Homebrew tap（prebuilt-binary 方式、署名保持のためソースビルドしない）
- submodule 追加、org profile 更新、web-site カタログ同期（EN/JA）、`check-org.sh` グリーン確認

**独立レビュー単位**: Phase 1（エンジン＋テスト）／ Phase 2（UI＋OS統合）／ Phase 3（リリース一式）の3つ。

## 5. Required API Scopes / Permissions

- **外部サービス: なし**（OAuth / 外部 API を一切使わない。SMB 認証情報はユーザーが登録する）
- **macOS 権限**:
  - 特別な TCC 許可は不要（ネットワークボリュームのマウントは Full Disk Access 等を要求しない）
  - Keychain: 自アプリの internet password への読み書きのみ
  - ログイン起動: `SMAppService` 登録時にシステム設定 → ログイン項目でユーザー承認（初回のみ）
  - **非サンドボックス**で Developer ID 配布（署名は Hardened Runtime 有効で notarize）

## 6. Series Placement

Series: util-series

Reason: util-series は CLI だけでなく GUI アプリ（csv-editor / claude-usage-lens-gui / active-lens-gui / quick-translate 等）も内包する系列である。share-mounter は「ローカル運用を助ける macOS ユーティリティ」であり、この括りに合致する。cybersecurity / lite / chatops 等のテーマには当たらない。

## 7. External Platform Constraints

- **ネットワーク依存**: SMB サーバへの到達性（VPN 必須の場合あり）。ログイン直後は未確立のことがある → 445 到達待ち＋バックオフで吸収する
- **NetFS の挙動**: マウント先は `/Volumes/<共有名>`。同名ボリュームが既存だと macOS が自動でサフィックス（`-1` 等）を付ける
- **macOS 13+ 前提**（`SMAppService`）
- **SMB 方言・認証**は OS の SMB スタックに委譲（アプリは NetFS 経由で叩くだけ）
- **レート制限: なし**（外部 API 非依存）
- **配布**: Gatekeeper / notarization 必須。ログイン項目登録は初回にユーザー承認が要る
- **UI 制約**: `MenuBarExtra` はアイコンの連続アニメーションに不向き（必要になれば AppKit `NSStatusItem` へ）

---

## Discussion Log

- **課題の出発点**: 「マウントして alias を起動項目に入れる」既存手法では、ログイン時に Finder ウィンドウが勝手に開き UX が悪い。ウィンドウを開かずにマウントだけしたい、という要望。
- **ウィンドウが開く原因の切り分け**: `open smb://…` や Finder「サーバへ接続」は Finder に表示を明示依頼するためウィンドウが開く。`mount_smbfs` / NetFS はマウントのみでウィンドウを開かない。AppleScript `mount volume` は macOS バージョンで挙動がぶれるため不採用。
- **マウント基盤の選定**: 当初 `mount_smbfs`（手軽案）と NetFS（本命案）を比較。要件「サイドバーにネットワークボリュームとして表示」を満たすには、`automountd`(root) 経由で `/Volumes` に自動配置し Keychain 連携もネイティブな **NetFS が最適**と決定。`mount_smbfs` はパスワードが `ps` に露出し得る点・`/Volumes` 作成に権限が要る点で不利。
- **要件の3点確定**: (1) SMB 専用、(2) サイドバーにボリュームとして表示、(3) 難しいことを考えず GUI で操作。これらが NetFS + Swift メニューバーアプリで同時に満たせることを確認。
- **機能拡張**: ログイン時 auto-mount に加え、複数共有をリスト登録し **メニューバーから選んで mount/unmount** できることを追加要件とした（ボリュームごとに auto-mount する/しない のフラグ ＋ ユーザー操作でのマウント/アンマウント）。
- **GUI のみに決定**: util-series 規約の「CLI 同居」からは逸脱するが、NetFS/Keychain 依存が強く CLI 単独価値が薄いため、意図的な逸脱として記録。テスト容易性はエンジン層のユニットテストで担保。
- **プラットフォーム**: Apple Silicon 専用・macOS 13+（`SMAppService` 要件）で合意。
- **堅牢性の肝**: ログイン直後のネットワーク未確立、スリープ復帰、VPN 再接続への追従を、445 到達待ち＋バックオフ、`NWPathMonitor`、スリープ復帰通知で吸収する設計を中核と位置づけた。これが単なる LaunchAgent の plist ではなくアプリ化する価値の中心。
- **ツール名**: `mount-keeper` / `volume-keeper` / `auto-mounter` と比較し、機能を素直に表す **share-mounter** に決定。
- **アイコン**: アプリアイコン（.icns 全解像度＋メニューバー用テンプレート）の作成を Phase 3 の成果物として明記。
