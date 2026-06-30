#!/usr/bin/env bash
# cloudkit.share 型を Production へデプロイする（Dashboard 手動操作が必要）。
#
# cktool では Production へのスキーマデプロイは不可。
# フェーズ1（Development で共有作成）完了後に実行してください。
#
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER="iCloud.com.itoguchi.genki.v2"

echo "=== Production スキーマデプロイ ==="
echo ""
./scripts/bootstrap-cloudkit-share-schema.sh check
echo ""
echo "【必須】CloudKit Dashboard で手動デプロイ:"
echo "  1. https://icloud.developer.apple.com/dashboard"
echo "  2. コンテナ ${CONTAINER}"
echo "  3. Deploy Schema Changes…"
echo "  4. cloudkit.share を含む変更を確認して Deploy"
echo ""
echo "デプロイ完了後: TestFlight の最新 Production 版で「共有リンクを送る」を再テスト"
