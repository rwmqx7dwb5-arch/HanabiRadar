# TESTFLIGHT_CLOUD_RELEASE — Mac 不要のクラウド署名・TestFlight 配信

**Mac は不要。** 署名付きビルドと TestFlight 配信は GitHub Actions の macOS ランナー上で
Fastlane（`match` / `gym` / `pilot`）＋ App Store Connect API キーで完結する。証明書もランナー上で
`match` が生成する。所有者（iPhone / Windows のみ）が用意するのは「アカウント・鍵・GitHub secrets」だけ。

構成:
- [`fastlane/Fastfile`](../fastlane/Fastfile) … `beta` レーン（署名 Release アーカイブ → TestFlight アップロード）
- [`fastlane/Appfile`](../fastlane/Appfile) / [`fastlane/Matchfile`](../fastlane/Matchfile) … アプリ識別子・証明書保管
- [`Gemfile`](../Gemfile) … fastlane 固定
- [`.github/workflows/release.yml`](../.github/workflows/release.yml) … 手動起動（`workflow_dispatch`）のみ

> このレーンは実シークレット無しでは実行できないため、初回実行が最初の検証になる（署名まわりは環境依存で
> 一度の微調整が要ることがある）。CI ログを見ながら詰める前提。

---

## 所有者が用意するもの（外部入力）

### 1. Apple Developer Program 登録（約 ¥15,800 / $99 per year）
[developer.apple.com](https://developer.apple.com/programs/) で登録。iPhone / ブラウザのみで可。
登録後、**Team ID**（Membership details に表示、例 `A1B2C3D4E5`）を控える → secret `DEVELOPMENT_TEAM`。

### 2. 本番用 Bundle ID を決めて App ID を登録
`com.example.hanabiradar` は**プレースホルダで提出不可**。自分のドメイン等で一意な ID
（例 `com.<yourname>.hanabiradar`）を決め、App Store Connect / Developer サイトで App ID を登録する
（Certificates, Identifiers & Profiles → Identifiers）。→ secret `APP_IDENTIFIER`。
- ローカルでビルドもするなら [`project.yml`](../project.yml) の `PRODUCT_BUNDLE_IDENTIFIER` も同値に更新
  （クラウドレーンは `xcargs` で上書きするので必須ではない）。
- WeatherKit を実機で使うなら、この App ID で WeatherKit capability を有効化（初回は未設定でもビルド・
  アップロードは可能。アプリ側に未取得時 fallback あり。詳細は後述）。

### 3. App Store Connect でアプリレコードを作成
[App Store Connect](https://appstoreconnect.apple.com) → My Apps → ＋ → 上の Bundle ID を選択して作成。

### 4. App Store Connect API キー（.p8）を発行
Users and Access → **Integrations** → App Store Connect API → 「＋」でキー生成。**Admin** ロール推奨
（初回に証明書を作成するため）。生成後に控える／取得するもの:
- **Key ID**（例 `2X9R4HXF34`）→ secret `ASC_KEY_ID`
- **Issuer ID**（ページ上部の UUID）→ secret `ASC_ISSUER_ID`
- **`AuthKey_XXXXXXXXXX.p8`**（ダウンロードは一度きり。安全に保管）

`.p8` は base64 にして secret `ASC_KEY_CONTENT` に入れる:
- Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8"))`
- macOS/Linux: `base64 -i AuthKey_XXXX.p8`

### 5. `match` 用のプライベート git リポジトリ
証明書・プロファイルを暗号化保存する**空のプライベートリポジトリ**を 1 つ作る（例
`rwmqx7dwb5-arch/HanabiRadar-certs`）。
- URL（HTTPS）→ secret `MATCH_GIT_URL`（例 `https://github.com/rwmqx7dwb5-arch/HanabiRadar-certs.git`）
- 暗号化パスフレーズを自分で決める → secret `MATCH_PASSWORD`
- リポジトリ書き込み用アクセス: `"<github-user>:<personal-access-token>"` を base64 化して
  secret `MATCH_GIT_BASIC_AUTHORIZATION`
  - PAT は該当 certs リポジトリの Contents 読み書き権限のみで可（fine-grained token 推奨）
  - 例（PowerShell）: `[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("USER:TOKEN"))`

---

## GitHub secrets 一覧（Settings → Secrets and variables → Actions）

| Secret | 内容 |
|---|---|
| `ASC_KEY_ID` | ASC API キーの Key ID |
| `ASC_ISSUER_ID` | ASC API キーの Issuer ID |
| `ASC_KEY_CONTENT` | `.p8` の base64 |
| `APP_IDENTIFIER` | 本番 Bundle ID |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID |
| `MATCH_GIT_URL` | 証明書保管リポジトリの HTTPS URL |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `user:token` の base64 |
| `MATCH_PASSWORD` | match 暗号化パスフレーズ（任意に決定） |

---

## 実行手順

1. 上の secrets をすべて登録。
2. GitHub → **Actions** → **TestFlight Release** → **Run workflow**（ブランチ `main`）。
3. 初回は `match` が Apple Distribution 証明書と App Store プロファイルを生成し、certs リポジトリに保存する。
4. `gym` が署名付き Release アーカイブを作り、`pilot`（`upload_to_testflight`）が App Store Connect へ送る。
5. 処理完了後、App Store Connect / iPhone の TestFlight アプリにビルドが現れる（処理に数分〜十数分）。
6. TestFlight でビルドを内部テスターに割り当て → iPhone の TestFlight で導入して実機テスト。

ビルド番号は `github.run_number`（毎回一意）を使うため、再実行のたびに新ビルドとして上がる。

---

## つまずきやすい点

- **署名の上書き**: 生成プロジェクトは test CI 用に `CODE_SIGNING_ALLOWED=NO`。`beta` レーンは `xcargs` で
  署名を有効化し match プロファイル（`match AppStore <bundle-id>`）を指定している。プロファイル名やチーム ID が
  合わないと export で失敗するので、初回はログを確認。
- **`match` の readonly**: 初回は `readonly:false`（証明書生成のため）。以後は
  [`fastlane/Fastfile`](../fastlane/Fastfile) で `readonly:true` にすると事故防止になる。
- **WeatherKit**: App ID に WeatherKit capability を付けて `.entitlements` に
  `com.apple.developer.weatherkit` を宣言するのは後続作業。未設定でもビルド・アップロード・測定 UX の
  テストは可能（気象取得は失敗時 fallback。§27 帰属 UI は実装済み）。
- **輸出コンプライアンス**: 独自暗号は未使用。App Store Connect の輸出コンプライアンス質問に沿って
  `ITSAppUsesNonExemptEncryption=false` を Info.plist に追加すると TestFlight 配信時の毎回の質問を省ける（後続）。
- **セキュリティ**: `.p8` や PAT は絶対にリポジトリへコミットしない（[`.gitignore`](../.gitignore) で `*.p8` を除外済み）。

関連: [APP_STORE_RELEASE.md](APP_STORE_RELEASE.md)（掲載素材・審査ノート）、
[APP_STORE_LISTING.md](APP_STORE_LISTING.md)。
