# PRIVACY

Hanabi Radar はカメラ・マイク・現在地・モーションという機微な情報を扱います。設計上の原則と、
App Store の App Privacy 回答の下書きをここに記します。実装状況は正直に区別します。

## 原則（コードで担保）

- **コア計算は端末内で完結。** 推定数理 `HanabiCore` は Apple フレームワークにもネットワークにも依存せず、
  距離・方向・位置・誤差の計算はすべてオンデバイス。
- **生の映像・音声を外部送信しない。** 検出はリングバッファ上の特徴量で行い、生メディアは常時保存しない
  （診断保存はユーザーの明示操作時のみ・§23）。独自解析サーバーは持たない。
- **広告事業者へ現在地を渡さない。** 収益化は `PurchaseService` / `AdService` プロトコル背後に隔離し、
  位置情報を広告 SDK へ渡す経路を設けない。プレミアム購入後は広告 SDK を初期化しない設計（§19.3）。
- **測定停止でセンサーを即停止。** バックグラウンド測定は行わず、測定中である旨を画面に明示する。

## 外部へ出るデータ（正直な明記）

- **WeatherKit（Apple）**: 音速補正のため、観測点および推定爆発地点の**座標を Apple の気象サービスへ問い合わせ**ます
  （現在条件の取得）。これは Apple のプライバシーポリシー下で処理され、第三者広告網とは無関係です。取得失敗時は
  観測点条件のみで計算を継続します。**座標を URL クエリに載せる等の不用意な送信は行いません。**
- **広告 SDK（将来・所有者側）**: 本番広告を導入する場合、SDK と ATT/UMP 同意の下でのみ動作し、初期設定は
  非パーソナライズ広告を優先します。導入前の現状ではネットワーク広告経路は存在しません。

## 権限と Purpose String

`HanabiRadar/App/Info.plist` に設定（日本語＝開発言語）。英語は
`HanabiRadar/Resources/en.lproj/InfoPlist.strings` で**ローカライズ済み**（`ja.lproj` も明示）:

| キー | 用途 |
|---|---|
| `NSCameraUsageDescription` | 花火の発光位置と方向の測定 |
| `NSMicrophoneUsageDescription` | 発光から爆発音までの時間差測定 |
| `NSLocationWhenInUseUsageDescription` | 観測地点を基準にした位置計算 |
| `NSMotionUsageDescription` | 端末の向き・角度の測定 |

現在地は **When In Use** のみ。Always は要求しません。

## データ削除

- 端末内の測定履歴は設定画面の「すべての履歴を削除」から削除できます（`SessionStore.deleteAll`・§20）。
- 生の診断メディアを保存した場合もユーザーが削除できます。

## Privacy Manifest

`HanabiRadar/App/PrivacyInfo.xcprivacy` を同梱。トラッキング無し・収集データ種別なしを宣言し、
実際に使用する **Required-Reason API** を宣言します:

| カテゴリ | 理由コード | 該当箇所 |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | 単位設定（`@AppStorage`）を自アプリの UserDefaults に保存 |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` | `ProcessInfo.systemUptime` による測定の共通時刻軸（端末内・アプリ内イベント間の経過時間） |

第三者 SDK を追加する際は、その SDK のマニフェスト・収集内容を確認し本ファイルと App Privacy 回答へ反映します。

## App Privacy 回答（下書き・提出時に確定）

- **収集してリンクするデータ**: なし（現状。アカウント・独自サーバーが無いため）。
- **トラッキング**: なし（ATT は実際に追跡を行う場合のみ要求）。
- **端末内のみで使用**: カメラ映像・マイク音声・モーション（推定にのみ使用、送信なし）。
- **粗い/正確な位置**: 位置は端末内の位置計算と WeatherKit 現在条件取得に使用。広告目的では使用しない。

> 実装が進み挙動が変わった場合は本書と App Privacy 回答を必ず更新し、実際の挙動と一致させること。
