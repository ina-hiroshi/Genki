#!/usr/bin/env bash
# 新 CloudKit コンテナ iCloud.com.itoguchi.genki.v2 の初回セットアップ。
#
# 事前準備（Developer Portal で1回だけ）:
#   1. https://developer.apple.com/account/resources/identifiers/list
#   2. 左上「+」→ iCloud Containers → Identifier: iCloud.com.itoguchi.genki.v2
#   3. App ID「com.itoguchi.Genki」→ iCloud → Edit → 新コンテナにチェック → Save
#
# 使い方:
#   ./scripts/setup-new-cloudkit-container.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="NUZ8XA844N"
CONTAINER="iCloud.com.itoguchi.genki.v2"
SCHEMA="cloudkit/GenkiSchema.ckdb"

echo "=== 新 CloudKit コンテナのセットアップ ==="
echo "コンテナ: ${CONTAINER}"
echo ""

echo "→ コンテナへのアクセス確認"
if ! xcrun cktool export-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER" \
  --environment development >/dev/null 2>&1; then
  echo "❌ コンテナ ${CONTAINER} にアクセスできません。"
  echo ""
  echo "Developer Portal で次を実行してください:"
  echo "  1. https://developer.apple.com/account/resources/identifiers/list"
  echo "  2. App ID「com.itoguchi.Genki」→ Capabilities → iCloud → Configure"
  echo "  3. Identifier: iCloud.com.itoguchi.genki.v2 で Register"
  echo "  4. App ID com.itoguchi.Genki → iCloud → Edit → 新コンテナにチェック → Save"
  exit 1
fi
echo "   ✅ コンテナにアクセス可能"
echo ""

echo "→ Development スキーマをインポート"
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
    echo "   ⚠️  Production: ${TYPE} がありません"
  fi
done

echo ""
echo "=== 次のステップ ==="
echo "1. CloudKit Dashboard → ${CONTAINER} → Deploy Schema Changes… → Production へデプロイ"
echo "2. ./scripts/upload-testflight.sh 1.0.21 で TestFlight にアップロード"
echo "3. TestFlight 1.0.21 で「共有リンクを送る」を試す"
echo ""
echo "旧コンテナ iCloud.com.itoguchi.genki は Production で CKShare 作成不可のため使用しません。"
