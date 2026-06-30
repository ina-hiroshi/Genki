#!/usr/bin/env bash
# cloudkit.share 型を Development で生成し、Production へデプロイする手順を支援する。
#
# 背景: cloudkit.share は Development で共有を1回作成すると JIT 生成される。
#       その後 Dashboard の Deploy Schema Changes で Production へ反映する必要がある。
#
# 使い方:
#   ./scripts/bootstrap-cloudkit-share-schema.sh check    # 現状確認
#   ./scripts/bootstrap-cloudkit-share-schema.sh wait   # 共有作成後、スキーマ差分を待つ（任意）
#
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="NUZ8XA844N"
CONTAINER="iCloud.com.itoguchi.genki.v2"
DASHBOARD_URL="https://icloud.developer.apple.com/dashboard"

check_schema() {
  local env="$1"
  xcrun cktool export-schema \
    --team-id "$TEAM_ID" \
    --container-id "$CONTAINER" \
    --environment "$env" 2>&1
}

echo "=== CloudKit 共有型ブートストラップ ==="
echo "コンテナ: ${CONTAINER}"
echo ""

DEV_SCHEMA="$(check_schema development)"
PROD_SCHEMA="$(check_schema production)"

echo "→ カスタム型 (Development / Production)"
for TYPE in FamilyGroup CheckIn CompletionLog; do
  dev_ok="❌"; prod_ok="❌"
  echo "$DEV_SCHEMA" | grep -q "RECORD TYPE ${TYPE}" && dev_ok="✅"
  echo "$PROD_SCHEMA" | grep -q "RECORD TYPE ${TYPE}" && prod_ok="✅"
  echo "   ${TYPE}: Dev ${dev_ok}  Prod ${prod_ok}"
done

echo ""
if diff <(echo "$DEV_SCHEMA") <(echo "$PROD_SCHEMA") >/dev/null 2>&1; then
  echo "→ Dev / Prod スキーマ: 同一（カスタム型のみ）"
else
  echo "→ Dev / Prod スキーマ: 差分あり（Deploy Schema Changes が必要な可能性）"
  diff <(echo "$DEV_SCHEMA") <(echo "$PROD_SCHEMA") || true
fi

echo ""
echo "※ cloudkit.share は export に表示されないことがあります。"
echo "  共有型の有無は Dashboard の「Deploy Schema Changes」で確認してください。"
echo ""

MODE="${1:-check}"
if [[ "$MODE" == "wait" ]]; then
  echo "→ Development スキーマの変化を待機中（最大 10 分）…"
  BASELINE="$(check_schema development | shasum)"
  for i in $(seq 1 60); do
    sleep 10
    CURRENT="$(check_schema development | shasum)"
    if [[ "$CURRENT" != "$BASELINE" ]]; then
      echo "   ✅ Development スキーマが更新されました（共有作成の可能性）"
      echo "   次: Dashboard → ${CONTAINER} → Deploy Schema Changes… → Production"
      exit 0
    fi
    echo "   …待機中 (${i}/60)"
  done
  echo "   ⚠️  スキーマ変化なし。TestFlight 1.0.25 で「共有リンクを送る」が成功したか確認してください。"
  exit 1
fi

echo "=== 手順（必須）==="
echo ""
echo "【フェーズ1】Development で共有型を生成"
echo "  1. TestFlight で 1.0.25 (Development) をインストール"
echo "  2. 家族 → 共有リンクを送る"
echo "  3. 共有シートが開けば OK（cloudkit.share 型が Development に生成される）"
echo ""
echo "【フェーズ2】Production へデプロイ"
echo "  1. ${DASHBOARD_URL}"
echo "  2. コンテナ ${CONTAINER} を選択"
echo "  3. Deploy Schema Changes… → cloudkit.share 等を含め Production へ Deploy"
echo ""
echo "【フェーズ3】Production 版をテスト"
echo "  1. TestFlight 1.0.26 (Production) をインストール"
echo "  2. 共有リンクを送る → 共有シートが開けば完了"
echo ""
