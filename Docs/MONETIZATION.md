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

## 実装状況（正直）

- 実装済み・CI 検証: プロトコル群、`StoreKitPurchaseService`（ビルド緑）、`MockPurchaseService`、`AdPolicy`、
  **同意アーキテクチャ（`ConsentService`/`ConsentGate`/`AdCoordinator`・`ConsentTests`）**、`.storekit` コンフィグ、
  **購入画面 UI（`PurchaseView` ＋ `PurchaseViewModel`・`PurchaseViewModelTests` ＋ UI スモーク・広告なし画面）**、テスト。
- 未実装（所有者側）: **実 UMP/ATT SDK の結線**（同意アーキテクチャは実装済み＝SDK 差込のみ）、実広告 SDK、本番広告 ID、
  App Store Connect の商品登録・実購入/復元検証。
