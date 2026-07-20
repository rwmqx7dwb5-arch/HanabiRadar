# SCIENCE_AND_MATH

Hanabi Radar の推定数理を定義します。すべて `HanabiCore` に実装され、`swift test` で検証されます。
本書の記号・規約はコードと一致させています。

## 1. 座標系と規約

| フレーム | 定義 |
|---|---|
| Pixel | フルピクセルバッファ座標。原点=左上、+u=右、+v=下。プレビュー View 座標ではない。 |
| Camera | +x=右、+y=下、+z=前方（シーン方向）。 |
| Device | 端末固定座標。Camera との関係は取り付け回転 `cameraToDevice` で表す（実機検証対象）。 |
| ENU | 局所水平座標。x=East, y=North, z=Up。 |
| ECEF | 地球中心地球固定直交座標（WGS84）。 |
| Geodetic | 緯度・経度（度）・高さ（m）。 |

方位角は真北から時計回り、[0, 360)。仰角は水平面からの角度。

## 2. カメラモデル（視線レイ）

内部行列 `K = [[fx,0,cx],[0,fy,cy],[0,0,1]]`。ピクセル `(u,v)` に対するカメラ座標の単位視線:

```
r_camera = normalize( K^-1 [u, v, 1]^T ) = normalize( ((u-cx)/fx, (v-cy)/fy, 1) )
```

内部行列は `ImagePoint` と同一のピクセル解像度で与える。検出器が縮小バッファ上で動作する場合は
`CameraIntrinsics.scaled(toWidth:height:)` で解像度変換する。プレビュー View 座標・アスペクトフィル・
ミラーリング・クロップの補正は Capture 層の責務であり、Pixel 座標へ正規化した上でコアへ渡す。

## 3. フレーム合成（Camera → ENU）

```
r_device = cameraToDevice · r_camera
r_ENU    = normalize( deviceToENU · r_device )
```

`deviceToENU` は発光時刻の端末姿勢（Core Motion）と真方位（Core Location）から Capture 層が構成する。
Core Motion の参照フレームの軸定義、前後カメラ、映像ミラーリング、手ぶれ補正、レンズ切替、真北/磁北の扱いは
**実機検証が必要な境界**であり、コアはこの合成済みクォータニオンを入力として受け取る。これによりコアの数理は
軸規約に依存せず単体検証できる（合成データテストは既知の `deviceToENU` を構成して全経路を検証する）。

方位・仰角:

```
azimuth   = atan2(r_ENU.x, r_ENU.y)          （東, 北）→ 北から時計回り
elevation = atan2(r_ENU.z, hypot(r_ENU.x, r_ENU.y))
```

## 4. 音速モデル

乾燥空気（温度 T[°C]）:

```
c_dry(T) = 331.3 · sqrt(1 + T / 273.15)
```

湿度補正（一次近似・数百分の一 m/s オーダー）。Tetens 式の飽和水蒸気圧 `esat` からモル分率 `x_w` を求め、

```
esat = 6.1078 · 10^( 7.5T / (T + 237.3) )   [hPa]
x_w  = (RH · esat) / P
Δc_humidity ≈ c_dry · 0.0507 · x_w
```

100% RH・20°C（x_w≈0.023）で約 +0.4 m/s になるよう較正。残差は誤差予算に算入する。

風補正: 気象データの風向は「風が吹いてくる方向（from）」で与えられることが多い。ENU 速度ベクトルへ変換:

```
windToward = fromDir + 180°
windENU = ( speed·sin(windToward), speed·cos(windToward), 0 )
```

音は爆発地点→観測点（単位ベクトル `k`）へ伝播するため、経路方向成分を加える:

```
c_eff = c_dry(T) + Δc_humidity + windENU · k
```

## 5. 距離と気象反復補正

本アプリの距離域では光の伝播時間は無視できるとして扱う。発光→爆発音の時間差 Δt に対し:

```
d = c_eff · Δt
```

反復（`BurstSolver.solve`）:

1. 観測点の気温で `c_eff` を初期化し仮の爆発地点を得る。
2. 仮地点で WeatherKit の現在条件を取得。
3. 観測点と仮地点の温度・湿度・気圧・風の平均を経路代表値として `c_eff` を更新。
4. 距離を再計算。変化量が閾値未満、または最大反復回数で停止。

WeatherKit を取得できない/失敗した場合は観測点条件のみで計算し、結果に「気象補正: 一部未適用」を表示する
（コアは実際に実行した反復回数を `iterations` として返す）。

## 6. 測地計算（WGS84）

定数: `a=6378137.0`, `f=1/298.257223563`, `e² = f(2−f)`。

Geodetic→ECEF:

```
N = a / sqrt(1 − e² sin²φ)
X = (N + h) cosφ cosλ
Y = (N + h) cosφ sinλ
Z = (N(1 − e²) + h) sinφ
```

ECEF→Geodetic は安定な不動点反復（`Geodesy.ecefToGeodetic`）。ENU 基底（ECEF 表現）:

```
east  = (−sinλ, cosλ, 0)
north = (−sinφ cosλ, −sinφ sinλ, cosφ)
up    = (cosφ cosλ, cosφ sinλ, sinφ)
```

爆発地点:

```
P_burst(ECEF) = P_observer(ECEF) + d · (ENU→ECEF)·r_ENU
```

を Geodetic へ逆変換。直下地点は同じ緯度経度で高度を地表側へ投影したもの。

### 高さの基準系（重要な注意）

コアの純幾何では観測点高度を**楕円体高**として扱う。Core Location の `altitude` は概ね平均海面（オルソメトリック）
基準であり、ジオイド高分（数十 m）の差がある。したがって:

- **海抜推定高度**（MSL）／**観測点からの相対高度**／**地上高**を区別する。
- ジオイド分離・地表標高の適用は app 側 `ElevationProvider` の責務。地表標高が得られないときは「地上高」と表示しない。

地上高の算出（`ElevationProviding` 実装時、`BurstSolver.solve` の最終段）:

```
g = ElevationProviding.elevation(at: subpoint)      // 直下地点の地表標高
heightAboveGround = burst.altitude − g              // g が得られたときのみ
subpoint.altitude = g
```

- 取得できない／`nil`／失敗のいずれでも `groundElevation`・`heightAboveGround` は `nil` のままとし、MSL・相対高度のみを提示する（`BurstSolver.solve` がこの分岐を保証し、`ElevationTests` が検証する）。
- 表示時は地表標高のデータ提供元・解像度・取得時刻またはデータ版（`ElevationSample.source / resolutionMeters / dataVersion`）を併記する。
- `burst.altitude` と `g` は同一の鉛直基準系である前提で差をとる。基準系が異なる場合の残差は誤差予算・注意書きで扱い、過剰な精度を主張しない。

## 7. 誤差推定（モンテカルロ）

各試行で入力を摂動して決定論ソルバを再実行し、母集団から区間・楕円・信頼度を得る（`UncertaintyEstimator`）。

摂動する量（1σ）: Δt、気温、風（水平成分）、音速モデル誤差、方位（鉛直軸まわり回転）、
仰角・姿勢（水平軸まわり傾き）、観測点水平/垂直位置（GPS 精度）。

出力:

- 距離の中央値・95%区間（2.5/97.5 パーセンタイル）
- 水平 95% 信頼楕円（(East,North) 共分散の固有分解、2自由度 χ²=5.991）
- 高度の中央値・95%区間
- 総合信頼度（0..1）と 高/中/低、および**主誤差要因**

主誤差要因は各要因の位置寄与を m 単位で比較して決定する（例: 距離寄与 `hypot(c·σ_Δt, Δt·σ_c)`、
方位寄与 `d·σ_heading[rad]`、GPS 水平 `σ_h` など）。方位精度が悪い状態で細かい緯度経度を強調表示しない。

### 誠実な表示ゲーティング（`EstimateReporter`）

「方位精度が悪い状態で細かい緯度経度を強調表示しない」（§14）を UI 任せにせず、コアの決定論ロジックとして
単体検証する。水平 95% 楕円の長半径 r と信頼度から表示精度を決める:

- 信頼度=低、または r > 300 m → `areaOnly`（鋭い点でなく区域として提示。低信頼時は楕円自体が信頼できないため）
- 50 m < r ≤ 300 m → `coarse`（点は出すが ± 半径を前面に）
- r ≤ 50 m → `fine`（フル精度）

`CoordinatePrecision.latLonDecimalPlaces`（fine=5, coarse=3, areaOnly=2 桁）で不確実性が支持する以上の
有効桁を印字しない。あわせて `weatherFullyApplied`（`iterations≥1`）・`groundHeightAvailable`
（`heightAboveGround != nil`）・`dominantFactor` を構造化して返し、View はこれをローカライズ表示するだけ
（文字列生成のみが app 側、判断はコア側で `EstimateReportTests` により検証）。しきい値は
`EstimateReporter.Thresholds` で調整できる。

## 8. 打ち上げ区域クラスタリング

単発の直下地点を発射地点とはみなさない。複数発の直下地点を局所 ENU（m）へ射影し、
**加重 DBSCAN**（`epsilonMeters`, `minPoints`）で密集領域を検出。各クラスタは MAD による外れ値除去後の
加重平均を中心とし、95% 半径・イベント数・信頼度を持つ。ノイズ点は外れ値として除外。複数の打ち上げ台は
複数クラスタとして返す。RANSAC 等は代替として将来比較対象とする。

### セッション集約（`SessionAggregator`）

「複数発を測るほど推定区域が改善する」動作を `SessionAggregator.summarize` がまとめる。各発の
`SessionBurst`（直下地点・信頼度・距離・高度）から、信頼度が `minConfidence` 未満のものを除外した上で
加重 DBSCAN へ渡し、`SessionSummary` を返す: クラスタ群（多い順）、総発数、採用発数、クラスタ帰属発数、
代表距離・代表高度（採用発のロバストな中央値）。どの密集領域にも属さない発はクラスタへ強制せずノイズとして
残す。単発の直下地点を発射地点として提示しないこの原則は `SessionAggregatorTests` で検証する。

## 9. 1台のiPhoneで確定できないこと

- 発射筒の正確な3次元位置（斜め打ち・玉の水平移動・単眼のため）。
- 花火高度の気象を地表気象で完全補正すること（代表性の限界）。
- 反響と実音の完全分離（複数候補を保持し、信頼度へ反映）。

これらは製品表示で誇張せず、推定・区域・誤差として提示する。

## 10. 独立実装によるクロス検証（合成データfixture）

`tools/reference/hanabi_reference.py` は同じ数式を Python で独立実装した参照オラクルである。標準ライブラリのみで、
音速（乾燥・湿度・風）、WGS84 測地変換、カメラレイ、既知真値からの爆発位置復元を計算し、
`HanabiCore/Tests/HanabiCoreTests/Fixtures/reference_scenes.json` を生成する。あわせて測地往復と真値復元の
自己検証を行う。

`ReferenceFixtureTests` はこの JSON を読み込み、Swift コアの出力が独立実装と一致することを検証する
（音速・カメラレイは ~1e-9、位置は緯度経度 1e-6°・高度/距離 0.1 m 以内、方位はラップ考慮）。言語・処理系を
またいで同一の答えになることを担保し、委託書 §24.2 の合成データ検証を二重化する。

再生成: `python tools/reference/hanabi_reference.py`。Python は乱数・時刻に依存しないため出力は決定論的で、
生成物はリポジトリにコミットする。
