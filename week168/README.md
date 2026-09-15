# Week168

一週間に自分で配分できる時間が有限であることを示し、その枠の中でやりたいことに
時間を割り当て続けるための iPhone アプリ。habiterm と TimeBranch の後継です。

T-01 ではプロジェクト骨格のみを用意しています。ドメインロジック、画面の詳細、
データ保存、署名・Team ID の設定は後続タスクで扱います。

## 構成

- `Week168`: SwiftUI + SwiftData のアプリ（現在はプレースホルダ画面のみ）
- `Packages/Week168Domain`: 外部依存も UI・永続化フレームワークへの依存もない Swift Package
- `Week168Tests`: アプリと Domain を import する最小のユニットテスト 1 件
- `Week168UITests`: 起動してプレースホルダを確認する UI テスト 1 件
- `project.yml`: XcodeGen の定義。生成した `.xcodeproj` はコミットしません

## ビルドとテスト

Swift 6 と iOS 18 以上の SDK・シミュレータを備えた Xcode、および XcodeGen が必要です。
Deployment Target は iOS 18.0、外部依存パッケージはありません。

リポジトリのルートから実行します。

```sh
cd week168
xcodegen generate
xcodebuild -project Week168.xcodeproj -scheme Week168 \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

インストール済みの iOS 18 以上のシミュレータの UDID を確認し、`SIMULATOR_ID` に設定します。

```sh
xcrun simctl list devices available
SIMULATOR_ID='<iOS 18 以上のシミュレータの UDID>'
xcodebuild -project Week168.xcodeproj -scheme Week168 \
  -configuration Debug -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:Week168Tests -only-testing:Week168UITests test
```

Domain の依存境界は次のコマンドで確認できます（検索結果なしなら成功）。

```sh
if rg -n 'import (SwiftData|SwiftUI)' Packages/Week168Domain/Sources; then
  exit 1
fi
```
