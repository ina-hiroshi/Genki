#!/usr/bin/env bash
# CloudKit コンテナの状態を確認し、Development スキーマを同期する。
#
# 使い方:
#   ./scripts/verify-cloudkit.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="NUZ8XA844N"
CONTAINER="iCloud.com.itoguchi.genki"
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
echo "=== CloudKit Dashboard で確認すること ==="
echo "https://icloud.developer.apple.com/dashboard"
echo ""
echo "1. コンテナ「${CONTAINER}」を選択"
echo "2. Schema → Record Types に FamilyGroup / CheckIn / CompletionLog がある"
echo "3. 右上「Deploy Schema Changes…」が表示されていれば Production へデプロイ"
echo "4. App ID「com.itoguchi.Genki」の Capabilities → iCloud → 上記コンテナにチェック"
echo ""
echo "※ cloudkit.share はシステム型のため Dashboard に表示されません。"
echo "  「Cannot create new type cloudkit.share」はスキーマ未デプロイではなく、"
echo "  ゾーン内に古い hierarchy share が残っている場合の誤表示です（1.0.16 で修正）。"
