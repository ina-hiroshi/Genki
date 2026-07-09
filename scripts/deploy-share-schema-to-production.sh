#!/usr/bin/env bash
# CloudKit スキーマ（Member / Reminder 等）を Production へデプロイする（Dashboard 手動操作が必要）。
#
# cktool では Production へのスキーマデプロイは不可。
# Development への import 完了後に実行してください。
#
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER="iCloud.com.itoguchi.genki.v2"
DASHBOARD="https://icloud.developer.apple.com/dashboard"

echo "=== Production スキーマデプロイ ==="
echo ""
./scripts/bootstrap-cloudkit-share-schema.sh check
echo ""
echo "【必須】CloudKit Dashboard で手動デプロイ:"
echo "  1. ${DASHBOARD}"
echo "  2. コンテナ ${CONTAINER}"
echo "  3. Deploy Schema Changes…"
echo "  4. Member / Reminder / FamilyGroup / CheckIn / CompletionLog を確認して Deploy"
echo ""
echo "デプロイ後の確認:"
echo "  ./scripts/bootstrap-cloudkit-share-schema.sh check"
echo "  → Member / Reminder が Prod ✅ になること"
echo ""
echo "その後: TestFlight 1.0.34+ で共有 → 参加 → メンバー/リマインダー表示を確認"
