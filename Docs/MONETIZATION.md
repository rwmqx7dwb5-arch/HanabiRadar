# MONETIZATION

委託書 §18–§19 に沿った収益化方針と実装状況。原則: **科学的な計算精度は無料版でも同一**。有料版は保存数・
広告・エクスポート・詳細誤差などの利便性のみを解放する。

## 無料版 / 買い切り版

| 項目 | 無料 | 買い切り（プレミアム） |
|---|---|---|
| 推定エンジン・精度 | 同一 | 同一 |
| 履歴保存 | 直近 3 セッション（`SessionStore` 保持上限） | 無制限 |
| 広告 | 履歴/セッション終了に限定・頻度上限 | 表示しない（SDK 初期化もしない） |
| エクスポート CSV/JSON/GeoJSON | — | 可（`SessionExporter`） |
| 詳細な誤差情報・比較 | 基本のみ | 詳細 |

保持上限は `SessionStore(retentionLimit:)`（無料=3、プレミアム=nil で無制限）。エンジンは共通のため、
無料版と有料版で `HanabiCore` の呼び出しは一切変えない。

## StoreKit 2（買い切り・non-consumable）

- 商品 ID（仮）: `com.example.hanabiradar.premium.lifetime`。価格はコードに固定せず App Store Connect で
  日本円の低価格帯（100 円台に近い）を選択できる構造。
- `PurchaseService` プロトコルで抽象化。実装 `StoreKitPurchaseService`:
  - 権限判定は `Transaction.currentEntitlements` から導出（UserDefaults の Bool で管理しない・§29）。
  - `purchasePremium()` は `product.purchase()` の結果を検証し、`.verified` のみ信頼して `finish()`。
  - `restore()` は `AppStore.sync()` 後にエンティトルメント再判定。
- テスト用に `MockPurchaseService`（actor）。`MonetizationTests` で購入→プレミアム化・キャンセル時非プレミアム・
  復元を検証。
- **購入画面 UI**: `PurchaseView`（`PurchaseViewModel` 経由で `PurchaseService` にバインド）。購入・購入復元・
  現在のエンティトルメント表示を持ち、価格は StoreKit の購入シートに委ねる（コード非固定）。この画面に広告は出さない。
  `PurchaseViewModelTests`（購入→プレミアム・キャンセル/失敗は非プレミアム・復元）と UI スモークで検証。
- ローカル検証用の `.storekit` コンフィグ（[`HanabiRadar.storekit`](../HanabiRadar.storekit)）を同梱（スキームへの結線は Xcode 側）。
- **所有者側の作業**: App Store Connect での商品登録、署名・実機/サンドボックス検証。

## 広告

- `AdService` プロトコル背後に SDK を隔離。既定は `NoOpAdService`。
- 配置規則は純粋な `AdPolicy` で単体検証（`MonetizationTests`）:
  - プレミアムは常に非表示。
  - **測定画面・カメラ起動前・爆発音待機中は常に非表示。**
  - インタースティシャルはセッション終了 / 履歴に限定し、頻度上限（既定 120 秒）を満たす場合のみ。
- **同意アーキテクチャ（§19.3・§20）**: `ConsentService`（既定 `DefaultConsentService` は `.unknown` で**フェイルクローズ**＝
  同意が解決するまで広告を出さず SDK も初期化しない）＋純粋な `ConsentGate`＋`AdCoordinator` で結線。非プレミアムは
  **同意解決後のみ** SDK を初期化し、パーソナライズは同意に厳密追従（既定は非パーソナライズ）。インタースティシャルは
  **同意ゲートと `AdPolicy` の両方**が許可した時のみ。プレミアムは同意を要求せず SDK も初期化しない。`ConsentTests` で検証。
- **所有者側の作業**: Google Mobile Ads SDK（SPM）と UMP 同意 SDK の導入、本番広告 ID の安全な分離
  （xcconfig 等・リポジトリに直書きしない・§29）、ATT の適切な要求、App Privacy への反映、テスト広告 ID での検証。

## サブスクリプション

導入しない（§19.2）。

## 広告 SDK 結線（実装済み・Phase 7）

- **SDK**: Google Mobile Ads **13.3.0**（`project.yml` で exact 固定。13.4 以降は Xcode 26.2 が必要で、CI は Xcode 16.4）。UMP は同 SDK に同梱。
- **同意**: `UMPConsentService`（UMP `ConsentInformation`/`ConsentForm` ＋ ATT）。UMP が広告不可なら `.denied`（SDK 非初期化）。
  TCF の `IABTCF_PurposeConsents` の目的 1/3/4 ＋ ATT 許可のときのみ `.personalized`、それ以外は非パーソナライズ。
  純粋な判定は `ConsentClassifier`（`ConsentClassifierTests`）。ATT は個別化が成立し得る場合のみ要求。
- **表示**: `GoogleAdService`（インタースティシャル、非パーソナライズ時は `npa=1`）。`AdsController` が起動時に同意解決・SDK 初期化、
  セッション終了（結果画面の「完了」）で `AdPolicy`（120 秒上限）＋同意ゲートを満たす場合のみ表示。プレミアムは同意要求も SDK 初期化もしない。
  UI テスト／`-mock-sensors` は常に無効。
- **ID**: `ADMOB_APP_ID` / `ADMOB_INTERSTITIAL_UNIT_ID`（`project.yml` の build setting → Info.plist）。**既定は Google 公式のテスト ID**。
  リリースでは xcconfig / fastlane で本番 ID に上書きすること（リポジトリに本番 ID を置かない・§29）。
- **プライバシー**: Info.plist に `NSUserTrackingUsageDescription`（JA/EN）と `SKAdNetworkItems`（Google 公式サンプルの全 ID）、
  `PrivacyInfo.xcprivacy` を tracking=true／広告識別子の収集宣言に更新。設定画面に UMP の「広告のプライバシー設定」（必要地域のみ）。
- **要確認（実機・アカウント）**: 本番 ID での配信、App Store Connect の App Privacy 回答（デバイス ID／広告データ、トラッキング）、EEA での同意フロー。

## 無料版の書き出し

- CSV/JSON/GeoJSON 書き出しはプレミアム限定。無料ユーザーは履歴画面の「書き出し（プレミアム）」から購入画面へ遷移する。

## 実装状況（正直）

- 実装済み・CI 検証: プロトコル群、`StoreKitPurchaseService`（ビルド緑）、`MockPurchaseService`、`AdPolicy`、
  **同意アーキテクチャ（`ConsentService`/`ConsentGate`/`AdCoordinator`・`ConsentTests`）**、`.storekit` コンフィグ、
  **購入画面 UI（`PurchaseView` ＋ `PurchaseViewModel`・`PurchaseViewModelTests` ＋ UI スモーク・広告なし画面）**、テスト。
- 未実装（所有者側）: 本番広告 ID の設定、
  App Store Connect の商品登録・実購入/復元検証。
