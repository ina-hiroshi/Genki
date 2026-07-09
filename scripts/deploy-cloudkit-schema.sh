#!/usr/bin/env bash
# CloudKit スキーマを Development にデプロイする。
#
# 事前準備（初回のみ）:
#   CloudKit Dashboard → API Access → 管理トークンを生成
#   xcrun cktool save-token --type management
#
# 使い方:
#   ./scripts/deploy-cloudkit-schema.sh
#
# 注意:
#   - Production へのデプロイは cktool 不可。Dashboard で手動実行。
#   - GenkiSchema.ckdb はライブの Users / cloudkit.share を含む（削除扱いを避ける）。
#
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="NUZ8XA844N"
CONTAINER="iCloud.com.itoguchi.genki.v2"
SCHEMA="cloudkit/GenkiSchema.ckdb"

echo "→ CloudKit スキーマを development にインポート"
xcrun cktool import-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER" \
  --environment development \
  --file "$SCHEMA"
echo "   ✅ development 完了"

echo ""
echo "→ development の型確認"
DEV_SCHEMA="$(xcrun cktool export-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER" \
  --environment development 2>/dev/null)"
for TYPE in FamilyGroup CheckIn CompletionLog Member Reminder; do
  if echo "$DEV_SCHEMA" | grep -q "RECORD TYPE ${TYPE}"; then
    echo "   ✅ ${TYPE}"
  else
    echo "   ❌ ${TYPE} がありません"
    exit 1
  fi
done

echo ""
echo "→ production 環境の確認"
PROD_SCHEMA="$(xcrun cktool export-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER" \
  --environment production 2>/dev/null)"
MISSING=0
for TYPE in FamilyGroup CheckIn CompletionLog Member Reminder; do
  if echo "$PROD_SCHEMA" | grep -q "RECORD TYPE ${TYPE}"; then
    echo "   ✅ ${TYPE}"
  else
    echo "   ❌ ${TYPE} がありません"
    MISSING=1
  fi
done

if [[ "$MISSING" -eq 1 ]]; then
  echo ""
  echo "⚠️  production に未デプロイの型があります（TestFlight は production を使用）"
  echo ""
  echo "   CloudKit Dashboard で Development → Production へデプロイしてください:"
  echo "   https://icloud.developer.apple.com/dashboard"
  echo "   1. コンテナ ${CONTAINER} を開く"
  echo "   2. 右上「Deploy Schema Changes…」（または Schema → Deploy to Production）"
  echo "   3. Member / Reminder / FamilyGroup / CheckIn / CompletionLog を確認してデプロイ"
  exit 1
fi

echo ""
echo "CloudKit スキーマのデプロイが完了しました。"
