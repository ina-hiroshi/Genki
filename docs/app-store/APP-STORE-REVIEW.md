# Genki 初回 App Store 審査チェックリスト

TestFlight ビルド **1.0.29** 向け。Connect 上の作業と API スクリプトの使い分けをまとめています。

## MCP / 自動化でできること

| 作業 | 方法 |
|------|------|
| 審査 Notes の登録 | `./scripts/app-store-review-setup.py set-review-notes`（API） |
| IAP 審査用スクショのアップロード | `./scripts/app-store-review-setup.py upload-iap-screenshot <画像>`（API） |
| ビルド + IAP を App Store 版に紐付け | `./scripts/app-store-review-setup.py prepare-version --version 1.0.29 --build 29`（API） |
| 状況確認 | `./scripts/app-store-review-setup.py status` |
| Connect 画面を開く | ブラウザ MCP で URL を開く（ログイン・2FA は手動） |

**API ではできないもの（手動必須）**

- Account Holder による契約・税務・銀行
- App Store 商品ページ（説明文・キーワード・6.7" スクショ等）
- App Privacy（プライバシー nutrition labels）
- 年齢制限・カテゴリ
- Paywall 画面の **実機/シミュレータ撮影**（撮影後は API でアップロード可）
- 最終的な「審査に提出」ボタン（Connect UI）

---

## 現在の Connect 状態（要確認）

`./scripts/app-store-review-setup.py status` で最新を確認してください。

想定される未完了項目:

1. **IAP `Genki Full Unlock`** — `MISSING_METADATA` → **Paywall 審査用スクショ** が未アップロード
2. **App Store 版** — ビルド未紐付け、審査 Notes 未設定、ストアメタデータ未入力

---

## Step 1: IAP を「提出準備完了」にする

### 1-a. Paywall スクショを撮る（自動）

```bash
cd /path/to/Genki
./docs/app-store/capture_screenshots.sh
./docs/app-store/capture_watch_screenshots.sh
python3 docs/app-store/generate_marketing_screenshots.py
```

- **iPhone App Store 一覧（5言語 × 4枚）**: `docs/app-store/marketing/{ja,en,es,pt-BR,ko}/01_home_1290x2796.png` 〜 `04_family_1290x2796.png`
- **Apple Watch（5言語 × 1枚）**: `docs/app-store/watch-screenshots/{locale}/watch_home.png`
- **IAP 審査用（1枚）**: `docs/app-store/Paywall-Review-Screenshot.png`（日本語 Paywall）
- **生キャプチャ（再編集用）**: `docs/app-store/screenshots/{locale}/`

手動で撮る場合（TestFlight **1.0.29** またはシミュレータ）:

1. オンボーディングで家族を作成（トライアル開始）
2. 家族タブ → **フル版を入手**（Paywall を開く）
3. 価格・機能一覧・**購入を復元** が写る画面をキャプチャ

保存先（推奨）:

```text
docs/app-store/Paywall-Review-Screenshot.png
```

### 1-b. API でアップロード

```bash
cd ~/開発/Genki
./scripts/app-store-review-setup.py upload-iap-screenshot docs/app-store/Paywall-Review-Screenshot.png
./scripts/app-store-review-setup.py status
```

IAP の `state` が `READY_TO_SUBMIT` になれば OK。

---

## Step 2: 審査 Notes（英語）

Connect → バージョン → **App レビューに関する情報** に貼るか、API で設定:

```bash
# 連絡先は環境変数で上書き可能
export REVIEW_CONTACT_PHONE="+81 80 XXXX XXXX"   # 先頭 + 国番号、スペース区切り（例: +81 80 1234 5678）
export REVIEW_CONTACT_EMAIL="your-support@example.com"
./scripts/app-store-review-setup.py set-review-notes --version 1.0.29
```

### 審査 Notes 本文（コピペ用）

```text
GENKI — App Review Notes

Sign-in: No separate Genkidayo account. The app uses the device iCloud (Apple ID) for CloudKit family sharing. Ensure iCloud is signed in on the test device.

Core test flow:
1. Launch Genkidayo → complete onboarding → create a family (you become the owner).
2. Full access for 14 days (trial starts when the family is created).
3. After trial: limited free tier (local check-in, SOS, and history viewing remain; family sync, invite links, widgets, and Watch require purchase).
4. Family tab → open Paywall (“Get Full Version”) — Non-Consumable IAP ¥1,200 (com.itoguchi.Genki.unlock).
5. For IAP on TestFlight: use a Sandbox Apple ID (Settings → App Store → Sandbox Account).
6. “Restore Purchases” is available on the Paywall and Family tab (Guideline 3.1.1).

Family purchase model:
- Only the family owner purchases once via IAP.
- Premium syncs to all members via CloudKit (premiumUnlockedAt on FamilyGroup).
- Participants do not need to purchase.

SOS: Always free, including after trial. This is not a medical diagnostic app — wellness check-in and family reminders only (Guideline 5.1.3).

No demo login is required — create a new family in onboarding. Use Sandbox IAP for purchase testing.
```

---

## Step 3: App Store 版 1.0.29 の準備

ビルド **29** が Connect で `VALID` になったら:

```bash
./scripts/app-store-review-setup.py prepare-version --version 1.0.29 --build 29
```

Connect UI で追加作業:

| 項目 | 内容 |
|------|------|
| ビルド | 1.0.29 (29) を選択 |
| App 内課金 | `Genki Full Unlock` にチェック |
| 説明文・キーワード | 5言語（アプリ内 Localizable に合わせる） |
| スクリーンショット | 6.7" 必須 — `docs/app-store/marketing/{locale}/` の 4 枚を各言語にアップロード |
| Apple Watch スクショ | Watch アプリ同梱済み — `docs/app-store/watch-screenshots/{locale}/watch_home.png` を各言語にアップロード |
| サポート URL | 公開ページ URL |
| プライバシーポリシー URL | 必須 |
| App Privacy | CloudKit・通知・購入履歴（Apple ID）を申告 |
| 年齢制限 | 4+（医療診断なし） |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption=false` 済み → 免除で OK |

---

## Step 4: Sandbox テスト

詳細は [`SANDBOX-IAP-TESTING.md`](SANDBOX-IAP-TESTING.md)。

審査前の確認:

- [ ] 14日トライアル → 制限表示
- [ ] Paywall 購入（Sandbox）
- [ ] 購入を復元
- [ ] 参加者端末で CloudKit premium 同期
- [ ] SOS は制限後も利用可

---

## Step 5: 審査提出

1. `./scripts/app-store-review-setup.py status` で IAP / Notes / ビルドを確認
2. Connect → **審査に提出**
3. 却下時は Guideline **3.1.1**（Restore）と **5.1.3**（医療表現）を再確認

---

## 審査で強調するポイント（5.1.3）

- アプリは **記録・共有・リマインド**（wellness）
- **診断・検知** とは言わない
- SOS は緊急連絡用 UI であり、医療機器ではない

---

## 連絡先・URL（Connect 入力用）

GitHub Pages（MioCam と同方式・リポジトリ直下）:

| 項目 | URL |
|------|-----|
| **プライバシーポリシー** | `https://ina-hiroshi.github.io/Genki/` |
| **サポート** | `https://ina-hiroshi.github.io/Genki/support.html` |
| 問い合わせメール | `itoguchi.app@gmail.com` |

初回公開前に `main` を push し、GitHub → Settings → Pages で **Deploy from branch: main / root** を有効化してください（未設定の場合）。

API スクリプトの審査連絡先は `REVIEW_CONTACT_*` 環境変数で上書きできます。
