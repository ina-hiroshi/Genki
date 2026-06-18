#!/usr/bin/env bash
# CloudKit スキーマを Development / Production にデプロイする。
#
# 事前準備（初回のみ）:
#   CloudKit Dashboard → API Access → 管理トークンを生成
#   xcrun cktool save-token --type management
#
# 使い方:
#   ./scripts/deploy-cloudkit-schema.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="NUZ8XA844N"
CONTAINER="iCloud.com.itoguchi.genki"
SCHEMA="cloudkit/GenkiSchema.ckdb"

echo "→ CloudKit スキーマを development にインポート"
xcrun cktool import-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER" \
  --environment development \
  --file "$SCHEMA"
echo "   ✅ development 完了"

echo ""
echo "→ production 環境の確認"
PROD_TYPES="$(xcrun cktool export-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER" \
  --environment production 2>/dev/null \
  | grep -c 'RECORD TYPE FamilyGroup' || true)"
if [[ "$PROD_TYPES" -ge 1 ]]; then
  echo "   ✅ production に FamilyGroup あり"
else
  echo "   ⚠️  production には FamilyGroup がありません（TestFlight は production を使用）"
  echo ""
  echo "   CloudKit Dashboard で Development → Production へデプロイしてください:"
  echo "   https://icloud.developer.apple.com/dashboard"
  echo "   1. コンテナ ${CONTAINER} を開く"
  echo "   2. 右上「Deploy Schema Changes…」（または Schema → Deploy to Production）"
  echo "   3. FamilyGroup / CheckIn / CompletionLog を確認してデプロイ"
  exit 1
fi

echo ""
echo "CloudKit スキーマのデプロイが完了しました。"
