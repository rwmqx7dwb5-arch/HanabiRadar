# APP_STORE_LISTING（ストア掲載素材・下書き）

委託書 §27 の掲載素材一式。**実際のビルド・署名・提出・掲載は macOS + Xcode + Apple Developer
アカウント保有者（所有者側）の作業**。ここは所有者がそのまま使える下書きで、公開前に商標・既存アプリ・
文言を確認して確定する。すべての表現は §4「科学的誠実性」に従い、確定情報を装わない。

関連: 提出プロセスとチェックリストは [APP_STORE_RELEASE.md](APP_STORE_RELEASE.md)、
プライバシー詳細は [PRIVACY.md](PRIVACY.md)。掲載用の静的ページは
[`Docs/support/index.html`](support/index.html)（Support URL）と
[`Docs/support/privacy.html`](support/privacy.html)（Privacy Policy URL）。

---

## 1. 名称・サブタイトル

| 項目 | 案 | 備考 |
|---|---|---|
| App 名（第一候補） | **Hanabi Radar** | 30 文字以内。商標/既存アプリ要確認。 |
| App 名（代替） | 花火レーダー / Hanabi Radar 花火の距離 | ローカライズ名は言語別に設定可。 |
| Subtitle（30 字以内） | 光と音で花火の位置を推定 | EN: *Estimate fireworks by light & sound* |

> 正式名称は公開前に変更可能な構造（`PRODUCT_NAME` / `CFBundleDisplayName` / ローカライズ）。

## 2. Promotional Text（170 字以内・更新可）

- **JA**: 花火大会を科学的に楽しむ。光と音の時間差から、花火の距離・方向・爆発地点を推定します。すべて誤差と信頼度つきの推定値です。
- **EN**: Enjoy fireworks with a scientific eye. From the flash-to-bang delay, estimate a burst's distance, direction, and position — always shown with its uncertainty and confidence.

## 3. Description

### 日本語

Hanabi Radar は、花火大会を「科学的に楽しむ」ための観測アプリです。

iPhone を花火へ向けて待つだけ。画面内の発光を検出し、数秒後に届く爆発音との時間差、
端末の姿勢・方位・現在地、そして気象条件を統合して、花火の爆発地点を 3 次元で推定します。

推定できること
・花火の爆発地点までの距離
・爆発した方向（方位・仰角）
・爆発地点のおおよその緯度・経度・高度
・爆発地点の直下に当たる地表の位置
・複数発から推定した打ち上げ区域
・各推定値の誤差範囲と信頼度

このアプリは「推定」アプリです。表示はすべて誤差と信頼度つきで、確定情報のようには見せません。
一台の iPhone だけでは発射筒の正確な位置は原則として確定できないため、発射位置は複数発から推定した
「打ち上げ区域」として提示します。気象は音速補正のために現在条件を取得し、取得時刻と提供元（Apple Weather）を
併記します。

計算はすべて端末内で行います。生の映像・音声・正確な位置を外部のサーバーへ送信しません。
測量・警備・軍事・捜査・災害対応などの専門用途を目的としないエンターテインメントアプリです。

無料で基本測定のすべてを利用できます。買い切りのプレミアムで、広告非表示・履歴無制限・
CSV/JSON/GeoJSON エクスポート・詳細な誤差情報が使えます。推定エンジンは無料版と同一です。

### English

Hanabi Radar turns a fireworks show into a science experiment you can hold in your hand.

Point your iPhone at the fireworks and wait. The app detects the flash on screen, times the bang
that arrives a few seconds later, and combines that delay with your device's attitude, heading, and
location — plus weather — to estimate where the burst happened in 3D.

What it estimates
• Distance to the burst
• Direction (azimuth and elevation)
• Approximate latitude, longitude, and altitude of the burst
• The ground point directly beneath the burst
• A launch area inferred from several bursts
• An uncertainty range and confidence for every value

This is an estimation app. Every value is shown with its uncertainty and confidence — never as a
confirmed fact. A single iPhone cannot pin down the exact mortar position, so the launch site is
presented as an estimated area from multiple bursts. Weather is fetched for sound-speed correction
and shown with its timestamp and source (Apple Weather).

All calculations run on device. Raw video, raw audio, and precise location are never sent to a
server. It is a consumer entertainment app — not a surveying, security, or surveillance tool.

Everything needed to measure is free. An optional one-time Premium removes ads and adds unlimited
history, CSV/JSON/GeoJSON export, and detailed uncertainty. The estimation engine is identical to
the free version.

## 4. キーワード（100 字以内・カンマ区切り）

`花火,花火大会,距離,位置,推定,音速,方位,hanabi,fireworks,distance,estimate,launch`

## 5. カテゴリ・年齢レーティング

- **Primary Category**: Entertainment（副次候補: Utilities）。
- **年齢レーティング回答（下書き）**: 暴力・性的表現・不適切表現なし。ギャンブルなし。
  位置情報を利用（機能目的）。→ 想定レーティング **4+**。提出時に質問へ正確に回答すること。

## 6. App Privacy（プライバシー栄養ラベル・回答下書き）

> 実挙動に一致させること。**現状 v1.0（サードパーティ広告 SDK 未結線）では、開発者が受け取る
> データはなく「Data Not Collected」が妥当**。広告 SDK を実際に結線したら本回答を必ず更新する。

- **Data Not Collected（現状）**: アカウント・独自サーバーが無く、映像/音声/位置/モーションは
  端末内の推定にのみ使用し、開発者のサーバーへ送信しない。
- **WeatherKit**: 音速補正のため座標を Apple の気象サービスへ問い合わせる。これは Apple の
  プライバシーポリシー下で処理され、開発者は位置を受領しない。
- **Tracking（ATT）**: なし。実際に追跡を行う場合にのみ ATT を要求する。
- **広告を有効化した場合（将来）**: 広告 SDK の収集データ種別（概ね「Identifiers」「Usage Data」等）と
  トラッキング有無を SDK のプライバシーマニフェストで確認し、本ラベルと `PrivacyInfo.xcprivacy` を更新する。

Privacy Manifest（`HanabiRadar/App/PrivacyInfo.xcprivacy`）で宣言済みの Required-Reason API:
UserDefaults（`CA92.1`・単位設定の保存）、System Boot Time（`35F9.1`・`systemUptime` による測定時刻軸）。

## 7. Review Notes（審査担当者向け・下書き）

```
Hanabi Radar is a consumer entertainment app for enjoying fireworks shows. It estimates where a
firework burst occurred in 3D from the flash-to-bang delay, the burst's position in the camera
frame, device attitude/heading/location, and weather.

Permissions:
- Camera & Microphone: detect the flash on screen and time the bang that follows, to compute
  distance from the light-to-sound delay. Raw media is not persisted or transmitted.
- Location (When In Use): the observation point for the geometry; also the coordinate used to fetch
  current weather for sound-speed correction. Not used for advertising.
- Motion: device orientation, to convert the on-screen burst position into a real-world direction.

WeatherKit is used to fetch current conditions for the observer/burst coordinates (sound-speed
correction). Apple Weather attribution is shown where weather is displayed.

All estimates are shown with an explicit uncertainty and confidence; nothing is presented as a
confirmed fact. The exact mortar position cannot be determined from one device, so the launch site
is shown only as an estimated area from multiple bursts.

Monetization: a single non-consumable "Premium" (ads off, unlimited history, export, detailed
uncertainty). The estimation engine is identical for free and premium users. Ads (if enabled) never
appear during measurement / camera start / bang-waiting and are frequency-capped. ATT is requested
only if actual tracking is performed.

To exercise the flow without live fireworks, launch arguments enable a mock-sensor mode used by the
automated UI tests (see TESTING.md).
```

## 8. StoreKit 商品説明

- **商品**: プレミアム（買い切り・non-consumable）。商品 ID 仮 `com.example.hanabiradar.premium.lifetime`。
- **内容**: 広告非表示・履歴無制限・CSV/JSON/GeoJSON エクスポート・詳細な誤差情報。
- **価格**: App Store Connect で日本円の低価格帯（100 円台目安）を選択。コード非固定。
  ローカル検証用の [`HanabiRadar.storekit`](../HanabiRadar.storekit) は displayPrice を仮値で保持
  （実価格は ASC 側で設定）。
- サブスクリプションは導入しない。購入復元・トランザクション検証・現在の entitlement 確認を実装済み
  （[MONETIZATION.md](MONETIZATION.md)）。

## 9. スクリーンショット構成案（6.9" / 6.7" / 5.5" ほか各サイズ）

1. **測定画面**: カメラプレビュー＋中央ガイド・水平器・コンパス・仰角・各種状態。キャプション「花火へ向けて待つだけ」。
2. **結果（数値）**: 距離・推定高度・方向・信頼度を大きく。キャプション「誤差と信頼度つきの推定」。
3. **結果（地図）**: 観測地点・視線・爆発地点・直下・95% 範囲。キャプション「爆発地点と直下を地図で」。
4. **推定打ち上げ区域**: 複数発のクラスタと半径。キャプション「複数発で区域を推定」。
5. **履歴**: 大会ごとのセッション一覧。キャプション「大会ごとに記録・共有」。
6.（任意）**誠実性**: 用語の区別（爆発地点／直下／推定区域／発射筒は確定不可）の説明カード。

> 撮影は Simulator/実機で暗色 UI（Light/Dark 両方）を確認。数値は実測または明示的な「デモ」を用い、
> 実在しない精度を演出しない。

## 10. アイコン・アセット

- **App Icon**: **ユーザー提供**の夜空＋花火デザイン（[`Assets.xcassets/AppIcon.appiconset`](../HanabiRadar/Resources/Assets.xcassets/AppIcon.appiconset)）。アイコン内表記は「Hanabi Radar」（Phase 6l で綴り修正済み）。
  1024×1024・不透過 RGB（α なし）。単一サイズを Xcode がダウンサンプルする構成。
- **Accent Color**: 花火色（Light/Dark 対応・[`Assets.xcassets/AccentColor.colorset`](../HanabiRadar/Resources/Assets.xcassets/AccentColor.colorset)）。
- **Support / Privacy Policy**: [`Docs/support/`](support/) の静的 HTML をホスティングして URL 化。

## 11. ローカライズ

- 初期対応: **日本語（開発言語）／英語**。
- Info.plist 権限説明文は `ja.lproj` / `en.lproj` の `InfoPlist.strings` でローカライズ済み。
- アプリ内 UI 文字列のカタログ化（`Localizable.xcstrings`）は後続インクリメントで実施
  （[KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) 参照）。
