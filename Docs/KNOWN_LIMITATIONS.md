# KNOWN_LIMITATIONS（既知の制限）

正直に列挙します。製品表示・審査資料でも同じ制限を明記します。

## 原理的な制限

- **発射筒位置は単一 iPhone では確定できない。** 斜め打ち・花火玉の水平移動・単眼のため、確定するのは
  「爆発地点（推定）」であり、発射位置は複数発からの「推定打ち上げ区域」として提示する。
- **高度気象の代表性。** WeatherKit の地表付近の値を花火高度へそのまま適用すると誤差が出る。風・湿度補正は
  補助的に用い、残差は誤差範囲へ反映する。
- **反響・複数同時爆発の曖昧性。** 反響音や近接する複数発は対応付けを誤らせる。複数候補を保持し、
  確信が低い場合はユーザーに選択肢を提示し、信頼度へ反映する。
- **方位（磁気）感度。** 方位誤差は遠距離で位置誤差を大きくする。金属・スピーカー・磁気源の影響を受ける。

## データ基準系

- Core Location の高度は概ね平均海面基準で、楕円体高やジオイド高と混同しない。地表標高が無い場合は
  「地上高」を表示しない（[SCIENCE_AND_MATH](SCIENCE_AND_MATH.md) §6）。
- コアには地上高の解決機構（`ElevationProviding` 契約＋`BurstSolver` 最終段）が実装済みで、取得不能・失敗・
  `nil` のいずれでも MSL・相対高度のみを返し AGL を捏造しないことを `ElevationTests` で検証する。ただし
  **実際の標高データ源（app 側 DEM アダプタ）は未接続**であり、それが接続されるまで AGL は提示されない。

## 実機で検証が必要な項目（未検証）

- Core Motion 参照フレームの軸定義と `deviceToENU` の符号・回転の正しさ。
- カメラ内部行列の配信可否、レンズ切替時の更新、手ぶれ補正による画角/遅延、映像ミラーリング。
- 高フレームレート設定の実効性、露出/フォーカス固定のタイミング、飽和時の中心推定。
- マイクの `measurement` モード適用可否、入力ゲイン/自動処理の影響、オーディオルート変更検出。

これらは Capture 層の実装とともに実機で測定し、`Docs`（実機検証結果）へ記録する。

### Capture 実機サービス（Simulator コンパイル済み・実機実行未検証）

- `Device{Camera,Audio,Motion,Location}CaptureService` は iOS Simulator でコンパイル検証済みだが、
  Simulator にはカメラ・マイク・モーションが無いため**実行時挙動は未検証**（CI は UI テストで常にモックを使用）。
- **共通時刻軸の整合**：Core Motion(`timestamp`=uptime)・Core Location(wall-clock→uptime正規化)・
  音声(`AVAudioTime` host time)を同一 uptime 軸へ寄せているが、音声/映像/モーション間の残留オフセットは実機較正が必要。
- **音声・映像の単一 AVCaptureSession 統合**（PTS 共有によるタイトな同期）は Phase 2（検出）で実施予定。現状の音声は
  AVAudioEngine 別経路であり、A/V 同期精度は実機で検証する。
- カメラのフレーム画素処理・内部行列のパイプライン供給は Phase 2 で結線する（現状はセッション確立と PTS 追跡のみ）。

### WeatherKit 実アダプタ（`WeatherKitProvider`・ビルド検証のみ・実行未検証）

- `WeatherKitProvider` は Apple 公式ドキュメントで API 面（`WeatherService.shared.weather(for:).currentWeather` の
  `temperature/humidity/pressure/wind`）を確認して実装し、**署名なしビルド（iOS CI）でコンパイル検証される**。
  ただし **実行には WeatherKit capability + entitlement と Apple Developer アカウント（所有者側）が必須**であり、
  実機・ネットワーク経由の取得結果は未検証。
- Apple の要件により、WeatherKit データを表示する箇所には **`WeatherService.shared.attribution`（提供元表示）が必須**。
  帰属表示 UI（`WeatherAttributionView`）を実装し Settings の「気象データ」セクションに配置した。ただし **実際の
  `attribution` 取得は WeatherKit entitlement が必要**で、未署名 CI／モックでは Apple の法的ページ URL への fallback
  （「Apple Weather」表記＋リンク）を表示する。今後ライブ気象値を表示する画面を実装したら、そこにも本ビューを併記すること。
- 取得失敗時はコア（`BurstSolver.solve`）が観測点条件のみで計算を継続し、結果に「気象補正: 一部未適用」を表示する
  設計（§5）。失敗時フォールバックの UI 表示は app 側で未実装。

## 製品化（掲載素材・アイコン・ローカライズ）の現状

- **App Icon / Accent**: **ユーザー提供**の夜空＋花火デザインを採用（元画像 1254px の黒縁を除去し 1024 不透過 RGB へ
  full-bleed 化。角の黒は iOS のスキュ―クル・マスクで丸められる）。Light/Dark Accent を同梱し `project.yml` に結線。
  **要確認事項2点**:
  1. **アイコン内の表記が「Hanabi Rader」**（"Radar" の綴り違い）。ストア名「Hanabi Radar」と不一致のため、提出前に
     画像を正しい綴りで差し替えるか、名称側を確定すること（アイコン画像はコードで安全に修正できない）。
  2. actool による実ビルドと実機/シミュレータでの見え方（マスク後の角・小サイズ視認性）は所有者側で確認する。
- **ローカライズ**: 権限説明文（InfoPlist.strings）に加え、**アプリ内 UI 文字列を String Catalog
  （`Localizable.xcstrings`・JA 原文＋EN）へ移行済み**（測定・結果・地図・履歴・設定・ランチャの見出し／ボタン／
  セクション／注記／状態表示）。ただし次は**意図的に原文（日本語）のまま**：
  - `Formatting` の値文字列（`海抜約`/`地上高約`/`観測点から`/`標高データなし` などの高さ・距離の書式）。これらは
    正確な文字列を検証する `FormattingTests` に固定されているため、テストをロケール非依存化する後続で対応する
    （信頼度ラベル `高/中/低` と主要因ラベルはビュー側で String Catalog を実行時参照して英語化済み）。
  - `DemoEstimate` のデモ文字列（ランチャの見本表示）。
  **アクセシビリティ仕上げ（VoiceOver ラベル網羅・Dynamic Type・Reduce Motion 検証）は未実施**。
- **掲載素材**: [APP_STORE_LISTING](APP_STORE_LISTING.md) と静的 Support/Privacy ページは下書きであり、連絡先メール・
  ホスティング URL・スクリーンショット・年齢レーティングの最終回答は所有者が確定する。
- **StoreKit 構成ファイル**: `HanabiRadar.storekit` はローカル検証用で、スキームには未結線（Xcode 側で有効化）。
  実価格は App Store Connect で設定する。
- **購入画面 UI**（`PurchaseView` ＋ `PurchaseViewModel`）は実装済み（`MockPurchaseService` で UI/VM を検証）。
  ただし**実購入・購入復元は StoreKit 商品登録＋実機/サンドボックス（所有者側）が必要**で、実行時挙動は未検証。
- **権限拒否時の限定モード（§21）**: 認可プローブ（`PermissionsReading`＝Camera/Mic/Location の実機認可読取＋Motion 可用性）
  ＋案内バナー（`PermissionBanner`）を実装。カメラ拒否＝測定不可案内／マイク拒否＝方向のみ／位置拒否＝緯度経度なし／
  モーション不可を区別し、権限系は「設定を開く」導線を出す。マッピングは `PermissionGuidanceTests`/`PermissionMappingTests` で
  検証し、degraded-mode の UI スモークで拒否時もクラッシュせず画面が出ることを確認する。**ただし対話的な代替入力
  （手動の観測地点指定・方向のみ測定 UI）は未実装**で、実機での実拒否時の挙動と 30 分連続試験は所有者側の実機検証が必要。
- **実広告 SDK と実 UMP/ATT SDK の結線** は未実装。**同意アーキテクチャ（`ConsentService`/`ConsentGate`/`AdCoordinator`）は
  実装・`ConsentTests` 済み**＝フェイルクローズ（同意解決まで広告なし・SDK 非初期化）／プレミアムは SDK 非初期化／
  パーソナライズは同意追従。所有者は Google UMP＋`ATTrackingManager` を `ConsentService` の実装として差し込むのみ。
  WeatherKit 帰属表示 UI は実装済み（上記・実 attribution 取得は entitlement 要）。

## 診断・自己テスト（§23）

- **診断（自己テスト）画面**（`DiagnosticsView`＋`DiagnosticsSelfTest`）を実装。合成シナリオ（既知の真値）で
  **実際の検出→対応付け→推定パイプライン**（`BurstPipeline`→`BurstSolver`）を走らせ、復元位置を真値と比較して
  PASS/FAIL を表示する。`DiagnosticsSelfTestTests`（真値復元）と UI スモーク（画面上で PASS 表示）で検証。実際の花火や
  実機センサーは不要で、iOS CI 上で毎回パイプラインの回帰確認になる。
- ただしこの自己テストは**合成入力**であり、`ReplayEngine`（録画済みセッションの再生・Capture 層で実装/テスト済み）を
  使った**実録データの回帰再生**、および実機で収録した診断メディアの読み込み UI は未実装。開発者導線は
  `AppLaunch.diagnosticsEnabled`（DEBUG は常時・Release は `-diagnostics`/UI テスト時のみ）でゲートしており、
  一般ユーザー向けリリースでは表に出さない。

## この開発環境に由来する制限

- 本リポジトリを作成した環境は **Windows** であり、**Swift ツールチェーンが無いため `swift build` /
  `swift test` を実行していない。** コードは Mac/Swift 環境でビルド・テストする前提で記述している。
  実行結果（テストの成否・実地精度）が確認できるまで、精度に関する数値目標は**未測定**として扱う。
- したがって「動作確認済み」と報告できるのは、Mac 側で実際にビルド・テストを実行した後になる。

## 精度に関する注意

- 距離・方向・最終位置の誤差は端末・環境に強く依存する。単一の絶対精度を宣伝文句にしない。
- 内部検証では距離誤差・方向誤差・最終位置誤差を分けて評価し、悪い結果も隠さず原因と実測値を報告する。
