# STATUS（開発状況の一覧）

最終更新: Phase 7。CI（`HanabiCore CI` / `iOS App CI`）が唯一の自動検証で、**開発環境（Windows）では Swift を実行していない**。
「実機未検証」は Mac + 実機 + Apple Developer アカウントが必要な項目。

## 完了（CI 検証対象）
- 推定数理コア `HanabiCore`、Capture 純ロジック、検出パイプライン、セッション集約、Python 参照オラクル照合
- 画面: 測定 / 結果（地図導線つき）/ 地図 / 履歴（書き出し）/ 設定 / 購入 / 診断 / 手動観測地点
- 永続化（SwiftData）、エクスポート（CSV/JSON/GeoJSON）、権限拒否モード、広告同意アーキテクチャ
- 地上高: 国土地理院 標高API（既定）＋キャッシュ。海外フォールバック（Open-Meteo）は既定 OFF
- 気象: 測定終了時に WeatherKit から観測点気象を取得（失敗時は固定値）、取得時のみ Apple 帰属表示
- 録画データの再生（診断画面: JSON 読込→本番と同じ解析を再実行、サンプル録画の書き出し）
- ローカライズ JA/EN（String Catalog＋`Formatting` の値文字列も言語切替）、Dynamic Type 対応のレイアウト、Reduce Motion 配慮、VoiceOver ラベル（測定画面）

## 所有者側の作業（Mac / 実機 / アカウント必須）
1. 実機で検証: カメラ内部行列・姿勢の符号・A/V 同期・マイク設定・30 分連続試験
2. WeatherKit capability + entitlement の有効化、実取得の確認
3. StoreKit 商品登録（App Store Connect）、実購入/復元のサンドボックス確認
4. Google UMP + ATT SDK を `ConsentService` に差し込む、広告 SDK 結線
5. 署名・TestFlight（`Docs/TESTFLIGHT_CLOUD_RELEASE.md`）、App Store 掲載素材の最終確定
6. 商用リリース時の標高データ源の確認（Open-Meteo 無料枠は非商用限定）

## 既知の未実装
- `DemoEstimate` のデモ文字列の EN 化（ランチャの見本表示のみ）
- 実機で収録した録画の自動書き出し（再生 UI と JSON 形式 `RecordedMeasurement` は実装済み。ライブ測定からの書き出しは未実装）

詳細は [KNOWN_LIMITATIONS](KNOWN_LIMITATIONS.md)。
