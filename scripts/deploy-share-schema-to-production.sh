#!/usr/bin/env bash
# CloudKit スキーマ（cloudkit.share / Member / Reminder 等）を Production へデプロイする（Dashboard 手動操作が必要）。
#
# cktool では Production へのスキーマデプロイは不可。
# Development で共有作成 + メンバー/リマインダー push 完了後に実行してください。
#
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER="iCloud.com.itoguchi.genki.v2"

echo "=== Production スキーマデプロイ ==="
echo ""
./scripts/bootstrap-cloudkit-share-schema.sh check
echo ""
echo "【Development で型を生成する手順】"
echo "  1. シミュレーターに iCloud サインイン"
echo "  2. ./scripts/bootstrap-share-via-simulator.sh --wait"
echo "     （GENKI_BOOTSTRAP_SHARE=1 で cloudkit.share + Member/Reminder を Dev に保存）"
echo ""
echo "【必須】CloudKit Dashboard で手動デプロイ:"
echo "  1. https://icloud.developer.apple.com/dashboard"
echo "  2. コンテナ ${CONTAINER}"
echo "  3. Deploy Schema Changes…"
echo "  4. cloudkit.share / Member / Reminder / FamilyGroup / CheckIn / CompletionLog を確認して Deploy"
echo ""
echo "デプロイ完了後: TestFlight の最新 Production 版で「共有リンクを送る」→ 参加 → メンバー/リマインダー表示を確認"
