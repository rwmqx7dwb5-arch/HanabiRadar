# TESTING

委託書 §24 に対応するテスト戦略。原則: **数理・判定ロジックは可能な限り決定論的な単体テストに落とし、
UI/フレームワーク層は Simulator ビルド＋UI スモークで検証**。実機のみで確認可能な項目は明示的に分離する。

## レイヤーと検証手段

| レイヤー | 手段 | どこで走る |
|---|---|---|
| `HanabiCore`（音速・測地・レイ・誤差・クラスタリング・集約・準備判定・表示ゲート） | `swift test` | CI（`HanabiCore CI`）/ 任意の Swift ツールチェーン |
| 合成データ（既知真値からの復元）§24.2 | `swift test`（`SyntheticFixtureTests`） | CI |
| 言語横断クロス検証 | Python 参照オラクル → fixture → `ReferenceFixtureTests` | Python は任意環境、Swift 側は CI |
| `HanabiCapture`（同期タイムライン・検出・対応付け・Replay） | `swift test` | CI（`HanabiCore CI` の capture ジョブ） |
| app 単体（`Formatting`・`SessionStore`・`SessionExporter`・`Monetization`・`BurstMapModel`） | XCTest（iOS Simulator） | CI（`iOS App CI`） |
| app UI スモーク（起動・測定/結果/地図/履歴/設定への遷移） | XCUITest（iOS Simulator・モックセンサー） | CI（`iOS App CI`） |

SwiftData の永続化は**インメモリ `ModelContainer`** で単体検証（`SessionStoreTests`）。StoreKit の実購入以外の
判定は `MockPurchaseService`／`AdPolicy` で検証。

## 言語非依存の参照オラクル

```bash
python tools/reference/hanabi_reference.py
```

同じ数式を Python で独立実装し、合成 fixture を再生成しつつ測地往復・真値復元を自己検証する。Swift の
`ReferenceFixtureTests` がこの fixture と照合し、**言語・処理系をまたいで同一の答え**になることを担保する
（[SCIENCE_AND_MATH §10](SCIENCE_AND_MATH.md)）。乱数・時刻に依存しないため出力は決定論的。

## CI

- `.github/workflows/core-ci.yml`（macos-14）: `HanabiCore` / `HanabiCapture` の `swift build` + `swift test`、
  SwiftLint（advisory）。
- `.github/workflows/ios-ci.yml`（macos-15）: XcodeGen 生成 → 署名なし Simulator ビルド → 動的解決した iPhone
  シミュレータで単体＋UI テスト。
- どちらも push（main）/ PR / 手動で発火。リリース前に Action を commit SHA 固定へ（供給網対策）。

## 合成データ・音響/映像テスト（§24.2/§24.3）

- 数学的に生成した既知の観測位置・姿勢・発光/音声時刻・気象から正解を作り、実装出力と比較（実装済み）。
- 単発/連続/同時/反響/拍手/会話/雷などの音響ケースは検出器の決定論ロジックで検証（`HanabiCapture` テスト）。

## 実機でのみ検証可能（未検証・要実機）

- Core Motion 参照フレームの軸・`deviceToENU` の符号、カメラ内部行列の配信/レンズ切替/手ぶれ補正、
  高フレームレート実効性、露出/フォーカス固定、飽和時中心推定、マイク `measurement` モード、
  オーディオルート変更、A/V 同期の残留オフセット。
- WeatherKit の実取得、StoreKit の実購入/復元、実広告表示・ATT/UMP。
- 30 分連続・長時間安定性・発熱時のフレームレート低下・権限拒否時の非クラッシュ。

これらは実機で測定し、距離誤差・方向誤差・最終位置誤差を分けて記録する。数値が期待より悪い場合も
閾値を都合よく変えず、原因と実測値を報告する（§24.4）。

## この開発環境の制限

本リポジトリは Windows 上で作成され Swift ツールチェーンが無いため、コミット環境では `swift test` を実行して
いない。代わりに **GitHub Actions（macOS ランナー）で全増分をビルド・テストし緑を確認**している。Python 参照
オラクルのみコミット環境で実行・検証済み。
