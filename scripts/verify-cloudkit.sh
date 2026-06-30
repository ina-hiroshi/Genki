#!/usr/bin/env bash
# CloudKit コンテナの状態を確認し、Development スキーマを同期する。
#
# 使い方:
#   ./scripts/verify-cloudkit.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="NUZ8XA844N"
CONTAINER="iCloud.com.itoguchi.genki.v2"
SCHEMA="cloudkit/GenkiSchema.ckdb"

echo "=== CloudKit 状態確認 ==="
echo "コンテナ: ${CONTAINER}"
echo ""

echo "→ Development スキーマを同期"
xcrun cktool import-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER" \
  --environment development \
  --file "$SCHEMA"
echo "   ✅ Development 完了"
echo ""

echo "→ Production スキーマ確認"
PROD_SCHEMA="$(xcrun cktool export-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER" \
  --environment production 2>&1)"

for TYPE in FamilyGroup CheckIn CompletionLog; do
  if echo "$PROD_SCHEMA" | grep -q "RECORD TYPE ${TYPE}"; then
    echo "   ✅ Production: ${TYPE}"
  else
    echo "   ❌ Production: ${TYPE} がありません"
  fi
done

echo ""
echo "=== 共有 (cloudkit.share) について ==="
echo "cloudkit.share はカスタム型ではなく、Development で共有を1回作成すると生成されます。"
echo "Production へ反映するには Dashboard の Deploy Schema Changes が必須です。"
echo ""
echo "  ./scripts/bootstrap-cloudkit-share-schema.sh"
echo ""
echo "=== CloudKit Dashboard ==="
echo "https://icloud.developer.apple.com/dashboard"
echo "コンテナ「${CONTAINER}」→ Deploy Schema Changes…"
