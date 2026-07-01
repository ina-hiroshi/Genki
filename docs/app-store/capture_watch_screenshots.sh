#!/bin/bash
# Apple Watch App Store 用スクリーンショット（5言語）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
WATCH_BUNDLE_ID="com.itoguchi.Genki.watchkitapp"
DERIVED="$REPO/.derivedData-screenshots"
OUT_DIR="$ROOT/app-store/watch-screenshots"

if [[ -z "${WATCH_SIM_ID:-}" ]]; then
  WATCH_SIM_ID="$(xcrun simctl list devices available -j \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
preferred = ('Apple Watch Series 11 (46mm)', 'Apple Watch Series 11 (42mm)', 'Apple Watch Ultra 3 (49mm)')
candidates = []
for runtime, devices in data.get('devices', {}).items():
    if 'watchOS' not in runtime:
        continue
    for d in devices:
        if d.get('isAvailable'):
            candidates.append((d.get('name', ''), d['udid']))
if not candidates:
    sys.exit(1)
for pref in preferred:
    for name, udid in candidates:
        if name == pref:
            print(udid)
            sys.exit(0)
print(candidates[0][1])
")"
fi

locales=(
  "ja|(ja)|ja_JP"
  "en|(en)|en_US"
  "es|(es)|es_ES"
  "pt-BR|(pt-BR)|pt_BR"
  "ko|(ko)|ko_KR"
)

mkdir -p "$OUT_DIR"

echo "==> Watch シミュレータ: $WATCH_SIM_ID"
echo "==> ビルド中..."
xcodebuild \
  -project "$REPO/Genki.xcodeproj" \
  -scheme GenkiWatch \
  -configuration Debug \
  -destination "platform=watchOS Simulator,id=$WATCH_SIM_ID" \
  -derivedDataPath "$DERIVED" \
  build > /dev/null

WATCH_APP="$DERIVED/Build/Products/Debug-watchsimulator/GenkiWatch.app"

echo "==> Watch シミュレータ準備..."
xcrun simctl shutdown "$WATCH_SIM_ID" 2>/dev/null || true
xcrun simctl boot "$WATCH_SIM_ID"
xcrun simctl bootstatus "$WATCH_SIM_ID" -b

for locale_spec in "${locales[@]}"; do
  IFS='|' read -r locale_id apple_lang apple_locale <<< "$locale_spec"
  out_locale="$OUT_DIR/$locale_id"
  mkdir -p "$out_locale"

  echo ""
  echo "==> 言語: $locale_id"

  xcrun simctl uninstall "$WATCH_SIM_ID" "$WATCH_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$WATCH_SIM_ID" "$WATCH_APP"

  xcrun simctl terminate "$WATCH_SIM_ID" "$WATCH_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch --terminate-running-process "$WATCH_SIM_ID" "$WATCH_BUNDLE_ID" \
    -e GENKI_WATCH_SCREENSHOT=1 \
    -AppleLanguages "$apple_lang" \
    -AppleLocale "$apple_locale"

  sleep 3
  outfile="$out_locale/watch_home.png"
  xcrun simctl io "$WATCH_SIM_ID" screenshot "$outfile"
  echo "    → $outfile"
done

echo ""
echo "完了: $OUT_DIR/{ja,en,es,pt-BR,ko}/watch_home.png"
