# Genki

家族がつながり、家族が安心する iOS アプリ。

コアループ（リマインド → 完了 → 家族へ通知 → リアクション）と、毎朝の「元気だよ」チェックイン（目覚ましショートカット連携）を毎日の習慣にします。世代を問わず、離れて暮らす家族みんなで使えます。

## 特長（v1）

- ワンタップ完了 → 家族にプッシュ通知 → スタンプでリアクション（つながりの往復）
- 毎日の「元気だよ」チェックイン（Siri / ショートカット / 目覚まし連携）
- 家族の今日の状態が一目でわかるホーム
- ホーム画面ウィジェット（開かずにちらっと確認）
- Apple Watch アプリ（手元で完了・チェックイン）
- 緊急 SOS と連絡チェーン
- オフラインファースト（SwiftData）＋ 家族間同期（CloudKit 共有）

## デザインテーマ

「シンプル・洗練 × あたたかい元気」。余白を活かしたミニマルなトーンに、アクセント1色（元気のオレンジ `#FF7A45`）。フォントは SF Pro Rounded。詳細は `Genki/DesignSystem/` とプランを参照。

## 技術スタック

- SwiftUI + SwiftData（ローカル / オフラインキャッシュ）
- CloudKit（CKShare による家族間共有・同期、CKSubscription によるプッシュ）
- WidgetKit（ウィジェット）/ watchOS（Watch アプリ）/ WatchConnectivity
- App Intents（ショートカット / 目覚まし連携）
- 最小 iOS 18.0 / watchOS 11.0、最新 SDK（iOS/watchOS 26）でビルド

## プロジェクト生成とビルド

このリポジトリは [XcodeGen](https://github.com/yonyz/XcodeGen) で `.xcodeproj` を生成します（`project.yml` が正）。

```bash
# 1. プロジェクト生成
xcodegen generate

# 2. ビルド（iOSアプリ + ウィジェット）
xcodebuild build -scheme Genki \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO

# 3. Xcode で開く
open Genki.xcodeproj
```

### Apple Watch アプリの有効化

watchOS シミュレータランタイムが必要です。

```bash
xcodebuild -downloadPlatform watchOS
```

導入後、`project.yml` の `Genki` ターゲットの依存にある `GenkiWatch` の `embed` のコメントを外し、`xcodegen generate` を実行してください。Watch のコードは `GenkiWatch/` に実装済みです。

## 実機 / iCloud のセットアップ（必須の手動作業）

CloudKit 同期・プッシュ・Watch・SOS は、署名済みの実機ビルドが前提です。

1. Xcode でプロジェクトを開き、各ターゲットの **Signing & Capabilities** で Team が **NUZ8XA844N**（MioCam / 連れ勉と同じ）になっていることを確認。
2. Apple Developer ポータルで以下を用意:
   - iCloud コンテナ `iCloud.com.itoguchi.genki`（CloudKit）
   - App Group `group.com.itoguchi.genki`
   - Push Notifications
3. CloudKit Dashboard で開発スキーマ（`FamilyGroup` 等のレコードタイプ）をデプロイ。
4. **Critical Alerts**（SOS がおやすみモード/消音を突破するため）は Apple への申請が必要。承認後 `Genki/Genki.entitlements` の該当キーを有効化。
5. 未署名 / iCloud 未設定でも、アプリはオフライン（ローカル）で安全に起動します（`FeatureFlags.cloudKitEnabled` で制御。シミュレータは既定で CloudKit 無効）。

詳しい目覚まし連携の設定は [`docs/ALARM_SHORTCUT_SETUP.md`](docs/ALARM_SHORTCUT_SETUP.md) を参照。

## TestFlight アップロード

輸出コンプライアンス（暗号化の輸出規制）は `Info.plist` の **`ITSAppUsesNonExemptEncryption = false`** で自動設定済みです。Genki は Apple 標準 API（HTTPS / CloudKit / プッシュ通知）のみを使い、**免除対象の暗号化のみ**と宣言しています。これにより App Store Connect で毎回「輸出コンプライアンス情報がありません」と手動入力する必要がなくなります。

```bash
chmod +x scripts/upload-testflight.sh

# ビルド番号を指定してアップロード（推奨: セマンティックバージョン形式）
./scripts/upload-testflight.sh 1.0.4
```

`VERSION` ファイルと `project.yml` の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` が同期されます。アップロード成功後、自動で git commit & push します。

手動で行う場合:

```bash
xcodegen generate
xcodebuild archive -scheme Genki -destination 'generic/platform=iOS' \
  -archivePath build/Genki.xcarchive -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath build/Genki.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
```

**注意:** 将来、独自の暗号化（非免除）を追加した場合は `ITSAppUsesNonExemptEncryption` を `true` に変更し、App Store Connect で輸出コンプライアンスを再設定してください。

## ディレクトリ

```
Genki/            iOSアプリ本体（Models / CloudKit / Features / DesignSystem / Intents ...）
GenkiWidget/      ホーム画面ウィジェット
GenkiWatch/       Apple Watch アプリ
Shared/           App/Widget/Watch 共有（スナップショット・カラー・定数）
docs/             セットアップガイド
project.yml       XcodeGen 定義（プロジェクトの正）
```

## App Store 審査の注意（5.1.3）

医療診断・検知をうたうと審査が厳しくなります。文言は「記録・共有・リマインド」に統一し、「診断・検知」は避けています。
