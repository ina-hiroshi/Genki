# Genki IAP Sandbox テスト手順

Product ID: `com.itoguchi.Genki.unlock`（非消耗型・¥1,200）

## 前提

1. App Store Connect で IAP の **配信可否** と **5言語ローカライズ** を完了
2. Paid Applications Agreement が有効
3. Xcode スキーム `Genki` に `Genki/Configuration/Genki.storekit` が設定済み（`project.yml` → `xcodegen generate`）

## ローカル（StoreKit Configuration）

1. Xcode で Genki スキームを選択
2. **Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration** = `Genki.storekit`
3. 実機またはシミュレータで Run
4. 家族タブ → **フル版を入手** → 購入ダイアログ（¥1,200 表示）
5. **購入を復元** ボタンが Paywall と家族タブの両方にあることを確認

## Sandbox（Connect 連携）

1. Connect → **ユーザとアクセス** → **Sandbox** → テスター Apple ID を作成
2. 実機: **設定 → App Store → Sandbox アカウント** でログイン
3. Development ビルドで購入 → Sandbox ダイアログでテスター ID を使用
4. 確認項目:
   - 購入後 `premiumUnlockedAt` が CloudKit に書き込まれる（オーナー端末）
   - 参加者端末で CK push 後に家族連携が復活
   - トライアル14日経過（日付変更または App Group キー `genki.trial.startDate` を調整）後、CloudKit 同期停止・招待不可
   - SOS・ローカルチェックイン・履歴閲覧は継続

## 審査提出

初回審査の全体チェックリストは [`APP-STORE-REVIEW.md`](APP-STORE-REVIEW.md) を参照。

1. Paywall 画面のスクリーンショットを IAP 審査用にアップロード
2. アプリ **新バージョン** の「App 内課金」で `Genki Full Unlock` を選択してから提出
3. 審査 Notes に: 14日トライアル → 制限 → 購入 → 復元 → 参加者端末の手順を記載

## Connect ローカライズ（45文字以内・確定文案）

| 言語 | 表示名 | 説明 |
|------|--------|------|
| 日本語 | Genki フル版 | 全機能を永久解放。1回の購入で家族全員。 |
| English | Genki Full Unlock | All features forever. One family purchase. |
| Español | Genki versión completa | Familia, widgets y Watch. Una compra. |
| 한국어 | Genki 풀 버전 | 가족·위젯·Watch 전 기능. 한 번 구매. |
| Português | Genki versão completa | Família, widgets e Watch. Uma compra. |

IAP 画像: `docs/app-store/GenkiFullUnlock-IAP-1024.png`（1024×1024）
