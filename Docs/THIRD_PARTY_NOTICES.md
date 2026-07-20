# THIRD_PARTY_NOTICES

サードパーティ依存とライセンス・データ収集の有無を記録する（§28）。

## 現在の実行時依存

**なし（第三者ランタイム依存は 0）。**

- ローカル Swift Package: `HanabiCore` / `HanabiCapture` は本リポジトリ内の自作パッケージ（外部取得なし）。
- Apple フレームワークのみ使用: SwiftUI, UIKit（限定）, AVFoundation, AVFAudio, CoreMedia, CoreVideo,
  Accelerate, CoreMotion, CoreLocation, WeatherKit, MapKit, SwiftData, StoreKit, OSLog, XCTest。これらは
  OS 同梱であり本ファイルの第三者告知対象ではない。

## ビルド専用ツール（実行時に同梱されない）

- **XcodeGen**（プロジェクト生成）: CI で Homebrew 導入。生成物 `*.xcodeproj` は git 管理外。
- **SwiftLint**（静的検査・advisory）: CI で Homebrew 導入。

これらはアプリバイナリに含まれない。

## 将来導入予定（所有者側・導入時に本ファイルへ追記）

- **Google Mobile Ads SDK**（SPM）＋ **UMP（User Messaging Platform）同意 SDK**: 広告導入時に追加。
  導入時に以下を必ず記載する — バージョン（固定）、ライセンス、SDK が収集するデータ種別、App Privacy への
  反映、Privacy Manifest への反映。本番広告 ID はリポジトリに直書きせず安全な設定へ分離（§29）。

## 方針

- 依存パッケージはバージョンを固定する。
- 追加時は「使用理由・ライセンス・データ収集の有無」を本ファイルへ記録する。
- 不要な Analytics SDK は追加しない（§20）。
