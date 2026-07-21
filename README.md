# Hanabi Radar

花火の発光と爆発音の時間差、カメラ内の爆発位置、端末の姿勢・方位・現在地、気象条件を統合して、
花火の爆発地点を3次元推定する iPhone 向けエンターテインメントアプリです。一般ユーザーが花火大会を
科学的に楽しむための製品であり、測量・警備・軍事・捜査などの専門用途を目的としません。

> **English summary.** Hanabi Radar is an iPhone app that estimates the 3D position of a
> firework burst from the flash-to-bang delay, the burst's position in the camera frame,
> the device attitude/heading/location, and weather. It is a consumer entertainment app,
> not a surveying or surveillance tool. Every output is an **estimate** with an explicit
> uncertainty and confidence; the app never presents an estimate as a confirmed fact.

---

## 現状（正直な開発ステータス）

このリポジトリは段階的に構築中です。**現時点で完成しているのは、Appleフレームワークに依存しない
推定数理コア `HanabiCore` とその検証テスト**です。カメラ・音声・センサー取得層、UI、WeatherKit連携、
SwiftData、StoreKit、広告などのApple依存層は後続で構築します。

| レイヤー | 状態 |
|---|---|
| `HanabiCore` 推定数理コア（音速・測地・カメラレイ・誤差伝播・クラスタリング） | **実装済み・CI緑** |
| `HanabiCore` 単体テスト＋合成データfixture（§24.1 / §24.2 相当） | **実装済み・CI緑（34テスト）** |
| Capture 純ロジック（同期タイムライン/正規化/リングバッファ/slerp/権限/ルート/Replay/ログ） | **実装済み・CI緑（28テスト）** |
| Capture 実機サービス（Camera/Audio/Motion/Location・AVFoundation等） | **実装済み・Simulatorコンパイル緑（実機実行は要検証）** |
| Detection（発光/爆発音/反響/対応付け・手動修正・end-to-endパイプライン） | **実装済み・CI緑（純ロジック検証）** |
| `HanabiCore` 気象/標高プロバイダ契約＋反復気象補正＋地上高解決（§13 の MSL/相対/地上高の区別） | **実装済み・CI緑** |
| セッション集約 `SessionAggregator` / 表示ゲーティング `EstimateReporter` / 測定準備 `CalibrationAssessor` / 誤差σ写像 `Inputs.fromMeasurement` | **実装済み・CI緑** |
| Python 参照オラクル＋クロス検証fixture（§24.2・音速/測地/レイ/位置復元を独立実装で照合） | **実装済み・CI緑（Swift↔Python 照合含む）** |
| WeatherKit 実アダプタ（app 側 `WeatherKitProvider`） | **CIビルド緑（実行は entitlement+実機=所有者側）** |
| DEM 標高アダプタ（app 側の具体実装。`ElevationProviding` 契約はコアに実装済み） | 未着手 |
| SwiftUI 画面（測定・結果・地図・履歴・設定・購入） | 骨組み＋結果/地図/履歴/設定デモ（`ResultView`/`BurstMapView`/`HistoryView`/`SettingsView`・単位切替が全画面反映）・**CIビルド＋単体＋UIスモーク緑** |
| SwiftData 永続化（セッション要約＋無料枠保持上限）／履歴画面 | **実装済み・要CI（`SessionStore`＋`SessionStoreTests` インメモリ検証／`HistoryView` デモ・UIスモーク）** |
| エクスポート（CSV/JSON/GeoJSON） | **実装済み・要CI（`SessionExporter`＋`SessionExporterTests`・GeoJSONは[経度,緯度]順）** |
| 地図表示 / エクスポート共有UI / app 全体の ModelContainer 結線 | 未着手 |
| StoreKit 2 買い切り・広告（アーキテクチャ） | **実装済み・要CI（`PurchaseService`＋StoreKit2実装=ビルド緑／`MockPurchaseService`＋`AdPolicy` 単体緑・実購入/実広告は所有者側）** |
| 購入画面UI（`PurchaseView`＋`PurchaseViewModel`：購入/復元/エンティトルメント・広告なし画面） | **実装済み・要CI**（`PurchaseViewModelTests`＋UIスモーク・`MockPurchaseService` 使用） |
| 権限拒否時の限定モード（認可プローブ＋案内バナー・§21） | **実装済み・要CI**（`PermissionsReading`＝Camera/Mic/Location 実機認可＋Motion 可用性／`PermissionBanner` がモード別に案内／`PermissionGuidanceTests`・`PermissionMappingTests`＋degraded-mode UIスモーク・実機の実拒否挙動は要検証） |
| 広告同意アーキテクチャ（`ConsentService`/`ConsentGate`/`AdCoordinator`・フェイルクローズ） | **実装済み・要CI**（`ConsentTests`／実 UMP/ATT SDK 結線は所有者側） |
| 本番広告ID/SDK結線・実 UMP/ATT SDK | 未着手（所有者側） |
| 診断（自己テスト）UI（§23）／ReplayEngine | **実装済み・要CI**（`DiagnosticsSelfTest`＝実パイプライン〔検出→対応付け→推定〕を合成シナリオで実行し真値照合／`DiagnosticsView`・開発者導線 `AppLaunch.diagnosticsEnabled`・`DiagnosticsSelfTestTests`＋UIスモークで PASS 検証。`ReplayEngine`〔録画セッション再生〕は Capture 層で実装・テスト済み） |
| Xcode アプリプロジェクト（`project.yml` → XcodeGen） | **骨組み実装済み・CI緑** |
| iOS Simulator ビルド/テストCI（署名なし・デバイス動的解決） | **緑（build＋Simulator上の単体テスト）** |
| App Icon（**ユーザー提供**の夜空＋花火デザイン・1024 不透過）・Accent Color（Light/Dark） | **実装済み**（`Assets.xcassets`・`project.yml` 結線・要 iOS CI・アイコン内表記は要確認: [KNOWN_LIMITATIONS](Docs/KNOWN_LIMITATIONS.md)） |
| App Store 掲載素材（[APP_STORE_LISTING](Docs/APP_STORE_LISTING.md)）・Support/Privacy 静的ページ | **実装済み**（名称/説明文 JA+EN/キーワード/審査ノート/App Privacy 回答・[静的ページ](Docs/support/)） |
| Privacy Manifest（Required-Reason API 宣言）・StoreKit 構成ファイル | **実装済み**（`PrivacyInfo.xcprivacy`＝UserDefaults `CA92.1`＋SystemBootTime `35F9.1`／[`HanabiRadar.storekit`](HanabiRadar.storekit)） |
| Info.plist 権限説明文の EN ローカライズ／UI 文字列のカタログ化 | **実装済み**（EN InfoPlist.strings＋UI 文字列 `Localizable.xcstrings` JA/EN・要 iOS CI）。`Formatting` の値文字列とデモ文字列は原文のまま（[KNOWN_LIMITATIONS](Docs/KNOWN_LIMITATIONS.md)） |

各項目の対応状況は `Docs/STATUS.md`（作成予定）と本README下部のチェックリストで管理します。

### ビルド環境についての重要事項

本アプリは iPhone ネイティブ（Swift / SwiftUI / AVFoundation / WeatherKit / MapKit / StoreKit）です。
**ビルド・実機テスト・署名・TestFlight/App Store 提出には macOS + Xcode + Apple Developer アカウントが必須**です。
これらは所有者側（Mac・Apple アカウント保有者）の作業となります。

一方、推定数理コア `HanabiCore` は Apple フレームワークに依存しないため、**任意の Swift ツールチェーンで
ビルド・テストを実行して科学的正しさを検証できます**。

---

## リポジトリ構成

```
HanabiRadar/
├── HanabiCore/                 推定数理コア（Swift Package・Apple 非依存）
│   ├── Package.swift
│   ├── Sources/HanabiCore/
│   │   ├── Math/               Vector3, Matrix3, Quaternion, Random, Statistics, Units
│   │   ├── Geodesy/            WGS84 / ECEF / ENU 変換
│   │   ├── Acoustics/          音速モデル（温度・湿度・風）
│   │   ├── Optics/             カメラレイ（内部行列の逆写像）
│   │   ├── Geometry/           視線合成・方位/仰角
│   │   ├── Model/              座標・気象・推定結果の型
│   │   ├── Estimation/         BurstSolver / UncertaintyEstimator
│   │   └── Clustering/         LaunchAreaClusterer（加重DBSCAN）
│   └── Tests/HanabiCoreTests/  単体テスト＋合成データfixture
├── Docs/
│   ├── ARCHITECTURE.md
│   ├── SCIENCE_AND_MATH.md
│   └── KNOWN_LIMITATIONS.md
├── .github/workflows/core-ci.yml
├── .swiftlint.yml
└── README.md
```

app 本体（Xcode プロジェクト・SwiftUI・Capture 等）は後続インクリメントで
`HanabiRadar/`（app ターゲット）と `project.yml` として追加します。

---

## 推定数理コアのビルドとテスト（Mac / Swift ツールチェーンで実行可能）

```bash
cd HanabiCore
swift build
swift test
```

`swift test` は音速計算・測地変換の往復・カメラレイ・視線合成・誤差伝播・クラスタリング、
および**既知の真値から爆発位置を復元する合成データテスト**を検証します。詳細は
[`Docs/SCIENCE_AND_MATH.md`](Docs/SCIENCE_AND_MATH.md) を参照してください。

### 言語非依存の参照オラクル（Swift 無しでも実行可能）

```bash
python tools/reference/hanabi_reference.py
```

Python 標準ライブラリのみで同じ数式を独立実装し、合成fixture（`reference_scenes.json`）を再生成しつつ
測地往復と真値復元を自己検証します。Swift の `ReferenceFixtureTests` はこの fixture と照合するため、
数理の正しさは Swift ツールチェーンが無い環境でも独立に確認できます（[SCIENCE_AND_MATH §10](Docs/SCIENCE_AND_MATH.md)）。

> Windows 上には Swift ツールチェーンが無いため、このリポジトリを作成した環境では
> `swift test` は実行していません。Mac もしくは Swift 対応環境で上記コマンドを実行してください。
> 上記 Python オラクルはこの環境で実行し、数理の一致を確認済みです。

---

## 科学的誠実性の原則（本アプリの根幹）

- 出力は**推定**であり、確定情報として表示しない。
- 用語を厳密に区別する:
  - **爆発地点** … 光と音から推定した空中の位置
  - **爆発地点の直下** … 爆発地点を地表方向へ投影した緯度・経度
  - **推定打ち上げ区域** … 複数の爆発地点・傾向から推測した区域
  - **実際の発射筒位置** … 1台のiPhoneだけでは原則として確定できない
- すべての値に誤差範囲と信頼度を付け、信頼度を下げた主因を明示する。
- 気象値は取得時刻とデータ提供元を併記し、現地実測値と混同しない。

---

## 完了条件チェックリスト（委託書 §31 対応）

凡例: [x] 実装済み / [ ] 未実装 / [外部] 所有者側（Mac・Apple・本番ID）作業待ち

- [x] 主要単体テストの作成（音速・測地・レイ・誤差・クラスタリング・合成データ）
- [x] 映像/音声/姿勢を共通時刻軸で扱う設計（`SynchronizedTimeline` 契約は Capture 層で実装予定）
- [ ] カメラ映像表示 / マイク入力取得（Capture 層）
- [ ] 発光候補・爆発音候補の検出と対応付け（Detection 層）
- [x] 距離計算・カメラレイ・緯度経度高度計算（`HanabiCore`）
- [x] 誤差範囲の算出（`UncertaintyEstimator`）＋ライブ精度→入力σ写像（`Inputs.fromMeasurement`・`UncertaintyInputsTests`）
- [x] 複数発クラスタリング（`LaunchAreaClusterer`）
- [x] 複数発のセッション集約（コア・`SessionAggregator`：信頼度ゲート＋加重DBSCAN＋代表統計・`SessionAggregatorTests`）
- [x] 測定準備アセスメント（コア・`CalibrationAssessor`：精度→測定可能/精度低下/測定困難＋限定要因・`CalibrationAssessorTests`）
- [x] 地上高の解決機構（コア・`ElevationProviding`）と地表標高欠如時の非表示（`ElevationTests`）
- [x] 独立実装（Python 参照オラクル）による数理クロス検証と合成fixture（§24.2）
- [x] 誠実な表示ゲーティング（コア・`EstimateReporter`：信頼度・95%楕円→表示精度／気象一部未適用／地上高有無・`EstimateReportTests`）
- [x] WeatherKit 実アダプタ（app・`WeatherKitProvider`／build-CI で検証・実行は entitlement+実機=外部）
- [ ] DEM 標高アダプタと失敗時フォールバックUI（app 側）
- [x] 誠実な表示フォーマット（app・`Formatting`：精度ゲート緯度経度／MSL・地上高区別／信頼度・主要因・`FormattingTests`）＋結果画面デモ（`ResultView`・UIスモーク）
- [x] 履歴の保存/削除/無料枠保持上限（`SessionStore`・`SessionStoreTests` インメモリ検証）＋履歴画面（`HistoryView`・UIスモーク）
- [x] エクスポート CSV/JSON/GeoJSON（`SessionExporter`・`SessionExporterTests`／GeoJSONは[経度,緯度]順）
- [x] 設定/単位切替（km⇄mi・℃⇄℉／`SettingsView`＋`Formatting.temperature`・UIスモーク）＋データ削除導線（§20・ストア結線時に有効化）
- [x] 地図表示（`BurstMapView`＋テスト可能な `BurstMapModel`：観測/爆発/直下＋水平95%円・`BurstMapModelTests`・UIスモーク）
- [ ] エクスポート共有UI・app 全体の ModelContainer 結線
- [x] 収益化アーキテクチャ（`PurchaseService`＋StoreKit2実装／`AdPolicy` 配置規則＋`AdService` 分離・`MonetizationTests`：購入→プレミアム／測定中は広告なし／頻度上限／プレミアムは広告停止）
- [x] 購入画面UI（`PurchaseView`＋`PurchaseViewModel`：購入/復元/エンティトルメント表示・広告なし・`PurchaseViewModelTests`＋UIスモーク） → [x] 広告同意アーキテクチャ（フェイルクローズ・`AdCoordinator`・`ConsentTests`） → [ ] 実 UMP/ATT SDK・本番広告ID 結線（所有者側）
- [x] 権限拒否時の非クラッシュ＋限定モード案内（`PermissionsReading` プローブ＋`PermissionBanner`＝カメラ/マイク/位置/モーション別案内＋設定導線・`PermissionGuidanceTests`/`PermissionMappingTests`＋degraded-mode UIスモーク） → [ ] 対話的代替モード（手動位置入力等）・30分連続試験（実機）
- [x] App Icon（**ユーザー提供**デザイン・1024 不透過 RGB・full-bleed 化）＋ Accent Color（Light/Dark）＋ `project.yml` 結線
- [x] App Store 掲載素材（[APP_STORE_LISTING](Docs/APP_STORE_LISTING.md)：名称・説明文 JA+EN・キーワード・審査ノート・App Privacy 回答・スクショ構成）
- [x] Support / Privacy Policy 静的ページ（[Docs/support/](Docs/support/)・JA+EN・自己完結 HTML）
- [x] Privacy Manifest の Required-Reason API 宣言（UserDefaults `CA92.1`＋SystemBootTime `35F9.1`）
- [x] StoreKit 構成ファイル（[`HanabiRadar.storekit`](HanabiRadar.storekit)・ローカル検証用）
- [x] Info.plist 権限説明文の英語ローカライズ（`en.lproj`/`ja.lproj` InfoPlist.strings）
- [x] アプリ内 UI 文字列のカタログ化（`Localizable.xcstrings` JA/EN・測定/結果/地図/履歴/設定/ランチャ） → [ ] アクセシビリティ仕上げ・`Formatting` 値文字列の英語化（後続）
- [x] WeatherKit 帰属表示 UI（`WeatherAttributionView`：Apple Weather マーク＋法的リンク／Settings の気象データ源セクション・entitlement 無時は fallback・`WeatherAttributionTests`＋UIスモーク）
- [x] 診断（自己テスト）UI（§23・`DiagnosticsSelfTest`＝実パイプラインを合成シナリオで走らせ真値照合／`DiagnosticsView`・開発者導線・`DiagnosticsSelfTestTests`＋UIスモークで PASS 検証）
- [ ] 対話的な限定モード（手動位置入力/方向のみ測定）・アクセシビリティ仕上げ（後続）
- [x] 必須ドキュメント一式（[ARCHITECTURE](Docs/ARCHITECTURE.md) / [SCIENCE_AND_MATH](Docs/SCIENCE_AND_MATH.md) / [PRIVACY](Docs/PRIVACY.md) / [MONETIZATION](Docs/MONETIZATION.md) / [TESTING](Docs/TESTING.md) / [APP_STORE_RELEASE](Docs/APP_STORE_RELEASE.md) / [APP_STORE_LISTING](Docs/APP_STORE_LISTING.md) / [THIRD_PARTY_NOTICES](Docs/THIRD_PARTY_NOTICES.md) / [KNOWN_LIMITATIONS](Docs/KNOWN_LIMITATIONS.md)）
- [外部] 署名・WeatherKit entitlement・本番広告ID・App Store Connect 設定・TestFlight 提出

詳細な既知の制限は [`Docs/KNOWN_LIMITATIONS.md`](Docs/KNOWN_LIMITATIONS.md) を参照。
