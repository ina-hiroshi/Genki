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

for ENV in development production; do
  echo "→ CloudKit スキーマを ${ENV} にインポート"
  xcrun cktool import-schema \
    --team-id "$TEAM_ID" \
    --container-id "$CONTAINER" \
    --environment "$ENV" \
    --file "$SCHEMA"
  echo "   ✅ ${ENV} 完了"
done

echo ""
echo "CloudKit スキーマのデプロイが完了しました。"
