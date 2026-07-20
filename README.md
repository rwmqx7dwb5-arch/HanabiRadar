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
| `HanabiCore` 推定数理コア（音速・測地・カメラレイ・誤差伝播・クラスタリング） | **実装済み** |
| `HanabiCore` 単体テスト＋合成データfixture（§24.1 / §24.2 相当） | **実装済み** |
| Capture（AVFoundation 同期取得・リングバッファ） | 未着手 |
| Detection（発光検出・爆発音検出・対応付け） | 未着手 |
| WeatherKit / ElevationProvider アダプタ | 未着手 |
| SwiftUI 画面（測定・結果・地図・履歴・設定・購入） | 未着手 |
| SwiftData 永続化・エクスポート | 未着手 |
| StoreKit 2 買い切り・広告・同意 | 未着手 |
| ReplayEngine / 診断 | 未着手 |
| Xcode アプリプロジェクト（`project.yml` → XcodeGen） | 未着手 |
| App Store 提出資料・アイコン・ローカライズ | 未着手 |

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

> Windows 上には Swift ツールチェーンが無いため、このリポジトリを作成した環境では
> `swift test` は実行していません。Mac もしくは Swift 対応環境で上記コマンドを実行してください。

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
- [x] 誤差範囲の算出（`UncertaintyEstimator`）
- [x] 複数発クラスタリング（`LaunchAreaClusterer`）
- [ ] WeatherKit 補正の実アダプタと失敗時フォールバックUI
- [ ] 地図表示・履歴保存/削除・エクスポート
- [ ] 購入/購入復元・広告テスト表示/同意・購入後の広告停止
- [ ] 権限拒否時の非クラッシュ動作・30分連続試験
- [外部] 署名・WeatherKit entitlement・本番広告ID・App Store Connect 設定・TestFlight 提出

詳細な既知の制限は [`Docs/KNOWN_LIMITATIONS.md`](Docs/KNOWN_LIMITATIONS.md) を参照。
