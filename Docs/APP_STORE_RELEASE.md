# APP_STORE_RELEASE

委託書 §27 の提出準備。**アプリのビルド・署名・提出は macOS + Xcode + Apple Developer アカウント保有者
（所有者側）の作業**である。ここでは所有者が使える下書きとチェックリストを提供する。名称・文言は公開前に
商標・既存アプリとの衝突を確認して確定すること。

## 名称・ストア文言（下書き）

- **App 名候補**: 「Hanabi Radar（花火レーダー）」ほか。※要商標/既存アプリ確認。
- **Subtitle 案**: 「光と音で花火の位置を推定」
- **Promotional Text 案**: 「花火大会を科学的に楽しむ。光と音の時間差から爆発地点を推定します。」
- **説明文（日本語・要約）**: カメラ・マイク・現在地・姿勢・気象を統合し、花火の距離・方向・爆発地点・
  推定打ち上げ区域を推定するエンタメアプリ。すべて推定値で、誤差と信頼度を明示します。測量・警備・軍事等の
  専門用途ではありません。
- **Description (English, summary)**: Estimate a firework burst's distance, direction, and 3D position from the
  flash-to-bang delay, the burst's position in frame, device attitude/heading/location, and weather. Every value is
  an estimate shown with its uncertainty and confidence. A consumer entertainment app — not a surveying or
  surveillance tool.
- **キーワード案**: 花火, 花火大会, 距離, 位置推定, 音速, hanabi, fireworks, distance, estimate

## 必須表示・URL（所有者が用意）

- **WeatherKit 帰属表示**: Apple Weather の所定の帰属（`WeatherService.shared.attribution` の名称＋法的ページ
  リンク）を、気象データを表示する画面に必ず出す。**未実装**（アダプタはあるが帰属 UI は要追加）。
- **Support URL**: サポート用の静的ページ（要作成・ホスティング）。
- **Privacy Policy URL**: プライバシーポリシーの静的ページ（[PRIVACY.md](PRIVACY.md) を基に作成・ホスティング）。
  アプリ内からも確認可能にする。

## 審査向け Review Notes（下書き）

- カメラ/マイク/現在地/モーションは、花火の発光と爆発音の時間差・方向・観測地点から位置を推定するために使用。
- 出力はすべて推定であり、確定情報として表示しない（発射筒位置は 1 台では確定不可と明記）。
- WeatherKit は音速補正のための現在気象取得に使用（座標を Apple の気象サービスへ問い合わせ）。
- 購入は買い切りの広告除去・保存無制限・エクスポート等。広告はプレミアム非表示、測定中は非表示。
- 追跡を行う場合のみ ATT を要求。

## StoreKit 商品説明（下書き）

- 商品: プレミアム（買い切り・non-consumable）。ID 仮 `com.example.hanabiradar.premium.lifetime`。
- 内容: 広告非表示・履歴無制限・CSV/JSON/GeoJSON エクスポート・詳細誤差。
- 価格は App Store Connect で日本円の低価格帯を選択（コード非固定）。

## その他アセット

- **App Icon**: 夜空＋花火のアクセント（要作成、全サイズ）。
- **スクリーンショット構成案**: ①測定画面（ガイド/水平器/方位）②結果（距離・信頼度）③地図（観測/爆発/直下/95%範囲）
  ④推定打ち上げ区域 ⑤履歴。
- **Light/Dark 表示確認**: 暗色 UI 基調・低輝度モード。両表示で確認。
- **年齢レーティング回答案**: 暴力/成人向け要素なし。位置情報利用あり。→ 低年齢帯想定（提出時に質問へ回答）。

## TestFlight 提出手順（所有者・macOS）

1. `xcodegen generate` でプロジェクト生成。
2. 署名（自動 or 手動）・Bundle ID・WeatherKit capability を設定。
3. Archive → App Store Connect へアップロード。
4. TestFlight で内部/外部テスターへ配布。

## リリース前チェックリスト

- [ ] 名称/文言の商標・既存アプリ衝突確認
- [ ] Bundle ID・署名・WeatherKit entitlement 設定
- [ ] StoreKit 商品を App Store Connect に登録・サンドボックス購入/復元確認
- [ ] 本番広告 ID を安全に分離（xcconfig）・テスト広告で確認・ATT/UMP 同意
- [ ] WeatherKit 帰属表示 UI を実装・表示確認
- [ ] Support / Privacy Policy ページ作成・アプリ内リンク
- [ ] Privacy Manifest・App Privacy 回答を実挙動と一致させる
- [ ] スクリーンショット・App Icon 用意
- [ ] 権限拒否時の非クラッシュ・30 分連続試験（実機）
- [ ] Release 構成ビルド・警告最小化
- [ ] CI の Actions を commit SHA 固定へ

## 所有者側のみが提供可能（外部入力待ち）

署名証明書、WeatherKit entitlement、StoreKit 商品構成、本番広告 ID、App Store Connect 設定、TestFlight 提出。
