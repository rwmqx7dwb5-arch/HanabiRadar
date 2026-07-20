# ARCHITECTURE

## 方針

- **数学とUIの分離**: 推定数理は Apple フレームワーク非依存の Swift Package `HanabiCore` に隔離する。
  これにより数理は Xcode・カメラ・実機なしで `swift test` により検証でき、UI 変更の影響を受けない。
- **実センサーとリプレイの差し替え**: 主要サービスは protocol で抽象化し、録画済みデータを入力として
  同じ結果を再現できるようにする（`ReplayEngine`）。
- **実機検証が必要な境界を明示**: Core Motion / Core Location の軸・参照フレーム、ミラーリング、
  手ぶれ補正、レンズ切替、真北/磁北などは実機検証対象。コアはこれらを解決済みの入力（`deviceToENU`,
  `cameraToDevice`）として受け取り、軸規約に依存しない。

## レイヤー責務

```
App
├── Presentation      Onboarding / Measurement / Result / Map / History / Settings / Purchase
├── Capture           CameraCaptureService / AudioCaptureService / MotionCaptureService /
│                     LocationCaptureService / SynchronizedTimeline
├── Detection         FlashDetector / AudioTransientDetector / EchoDetector /
│                     AscentTrailDetector / EventPairingEngine
├── Estimation        （HanabiCore）CameraRaySolver / SoundSpeedModel / Geodesy /
│                     BurstSolver / UncertaintyEstimator / LaunchAreaClusterer
├── Data              SessionRepository / SwiftDataModels / WeatherProvider /
│                     ElevationProvider / ExportService
├── Monetization      PurchaseService / AdService / ConsentService
└── Diagnostics       ReplayEngine / SensorRecorder / CalibrationService / StructuredLogger
```

`Estimation` の中核は `HanabiCore`。`Data` の `WeatherProvider` は `HanabiCore.WeatherConditionsProviding`
に適合させ、WeatherKit を隠蔽する。

## データフロー

```
Capture(同期取得) → Detection(発光/爆発音候補) → EventPairingEngine(対応付け・複数仮説)
   → BurstSolver(視線レイ→距離→WGS84, 気象反復) → UncertaintyEstimator(誤差/信頼度)
   → SessionRepository(SwiftData) → LaunchAreaClusterer(区域) → Presentation(結果/地図/履歴)
```

## 同期タイムライン（SynchronizedTimeline）

すべてのイベントを単調増加の共通時刻軸へ変換する。映像・音声は可能な限り同一 `AVCaptureSession` で取得し、
各サンプルの Presentation Timestamp を基準にする。**コールバック受信時刻で同期しない。** モーション/位置/方位は
本来のタイムスタンプを保持し、発光時刻の前後サンプルからクォータニオン補間（slerp）で姿勢を求める。
位置・方位は測定時刻との差も品質評価に含める。

保存する時刻:
映像 PTS / 音声 PTS / Core Motion timestamp / Core Location timestamp / CLHeading timestamp /
WeatherKit 取得時刻 / セッション開始ホスト時刻。

## HanabiCore の公開境界

- 型: `GeodeticCoordinate`, `ImagePoint`, `CameraIntrinsics`, `WeatherConditions`, `BurstEstimate`,
  `UncertaintyResult`, `ErrorEllipse`, `LaunchCluster` など。
- protocol: `WeatherConditionsProviding`（app 側で WeatherKit に適合）。
- 主要API: `BurstSolver`, `UncertaintyEstimator`, `LaunchAreaClusterer`, `Geodesy`, `SoundSpeedModel`,
  `CameraRaySolver`, `LineOfSight`。
- 全推定結果に `calculationVersion` を保持し、アルゴリズム変更後の再計算・回帰比較を可能にする。

## 並行性

Swift Concurrency を用いる。取得系は専用キュー、推定は値型（`Sendable`）で副作用を持たず、
モンテカルロは決定論 RNG（`SplitMix64`）でシード固定により再現可能。

## Xcode プロジェクト生成

`.xcodeproj` はテキストで検証可能な `project.yml`（XcodeGen）を正とし、Mac 上で `xcodegen generate` により
生成する（後続インクリメントで追加）。これにより Windows 上での不正な `project.pbxproj` 手書きを避ける。
