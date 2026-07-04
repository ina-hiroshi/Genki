#!/usr/bin/env bash
# 共有リンクフローの UI テストを一括実行する。
#
# 使い方:
#   ./scripts/test-share-flow.sh              # 全テスト（CloudKit テストは iCloud 必須）
#   ./scripts/test-share-flow.sh --offline    # 参加フロー注入テストのみ（iCloud 不要）
#   ./scripts/test-share-flow.sh --wait       # iCloud 未サインイン時に設定を開いて待機
#
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR_NAME="${GENKI_SIMULATOR:-iPhone 17}"
DERIVED="build/DerivedData-share-test"
WAIT_MODE=false
OFFLINE_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --wait) WAIT_MODE=true ;;
    --offline) OFFLINE_ONLY=true ;;
  esac
done

open_simulator_icloud_settings() {
  xcrun simctl boot "${SIMULATOR_NAME}" 2>/dev/null || true
  open -a Simulator
  sleep 2
  xcrun simctl openurl booted "App-prefs:APPLE_ACCOUNT" 2>/dev/null \
    || xcrun simctl openurl booted "prefs:root=APPLE_ACCOUNT" 2>/dev/null \
    || true
}

run_tests() {
  local -a only_flags=()
  if $OFFLINE_ONLY; then
    only_flags=(
      -only-testing:GenkiUITests/ShareFlowUITests/testJoinFamilyWithInjectedPendingShare
    )
  else
    only_flags=(
      -only-testing:GenkiUITests/ShareFlowUITests/testPrepareShareLinkIncludesHTTPSURL
      -only-testing:GenkiUITests/ShareFlowUITests/testShareButtonOpensShareUI
      -only-testing:GenkiUITests/ShareFlowUITests/testJoinFamilyWithInjectedPendingShare
    )
  fi

  xcodegen generate >/dev/null
  xcrun simctl boot "${SIMULATOR_NAME}" 2>/dev/null || true

  local log
  log="$(mktemp)"
  set +e
  xcodebuild test \
    -scheme GenkiUITests \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
    -configuration Debug \
    -derivedDataPath "$DERIVED" \
    "${only_flags[@]}" \
    2>&1 | tee "$log"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ "$status" -ne 0 ]] && ! $OFFLINE_ONLY; then
    if grep -qE "iCloud|auth token|genki-bootstrap-fail" "$log"; then
      rm -f "$log"
      return 2
    fi
  fi

  rm -f "$log"
  return "$status"
}

echo "=== Genki 共有リンク UI テスト ==="
echo "シミュレーター: ${SIMULATOR_NAME}"
if $OFFLINE_ONLY; then
  echo "モード: オフライン（参加フロー注入のみ）"
fi
echo ""

attempt=1
max_attempts=1
if $WAIT_MODE && ! $OFFLINE_ONLY; then
  max_attempts=40
fi

while (( attempt <= max_attempts )); do
  echo "→ 試行 ${attempt}/${max_attempts}"
  set +e
  run_tests
  result=$?
  set -e

  if [[ "$result" -eq 0 ]]; then
    echo ""
    echo "✅ 共有リンク UI テスト成功"
    exit 0
  fi

  if [[ "$result" -eq 2 ]] && $WAIT_MODE; then
    echo ""
    echo "⚠️  iCloud サインインが必要です（CloudKit 共有テスト用）"
    open_simulator_icloud_settings
    echo "   サインイン後、30秒ごとに再試行します…"
    sleep 30
    attempt=$((attempt + 1))
    continue
  fi

  echo ""
  echo "❌ テスト失敗（exit ${result}）"
  if ! $OFFLINE_ONLY; then
    echo "   iCloud 未設定の場合: ./scripts/test-share-flow.sh --offline"
    echo "   iCloud 待機付き:     ./scripts/test-share-flow.sh --wait"
  fi
  exit "$result"
done

echo "❌ iCloud サインイン後も CloudKit テストが失敗しました"
exit 1
