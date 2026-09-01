#!/usr/bin/env bash
# Capture raw marketing screenshots for all languages × screens.
#
# Requires the app to already be installed on the target simulator. Re-launches
# the app with different launch args (read by the DEBUG-only `MarketingScreen`
# pre-routing in AdhkarApp.init) and captures via `xcrun simctl io screenshot`.
#
# Usage: ./scripts/capture_marketing.sh [SIM_UDID] [RAW_SUBDIR]
#   SIM_UDID     defaults to iPhone 17 Pro Max
#   RAW_SUBDIR   "raw" for iPhone (default), "raw_ipad13" for iPad

set -euo pipefail

SIM="${1:-74883169-D394-4358-A8AD-283CEF0C74CF}"   # iPhone 17 Pro Max default
RAW_SUBDIR="${2:-raw}"
# iPad cold-starts are slower than iPhone — scale all waits up via
# SLEEP_SCALE=3 ./scripts/capture_marketing.sh <ipad-udid> raw_ipad13
SLEEP_SCALE="${SLEEP_SCALE:-1}"

zzz() { sleep "$(echo "$1 * $SLEEP_SCALE" | bc)"; }
BUNDLE="com.tadevv.munajat"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
RAW_DIR="$REPO/marketing/$RAW_SUBDIR"

# Three favorite categories pre-seeded so the favorites screen has content
FAV_IDS='("morning_adhkar","evening_adhkar","sleep_adhkar")'

declare -a LANGS=("fr" "en" "ar")
declare -A LOCALES=( [fr]="fr_FR" [en]="en_US" [ar]="ar_SA" )
declare -a SCREENS=("home" "context_picker" "context_detail" "detail" "post_prayer" "review_session" "settings")

launch() {
  local lang="$1" locale="$2" screen="$3"
  xcrun simctl terminate "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
  zzz 0.3
  xcrun simctl launch "$SIM" "$BUNDLE" \
    -AppleLanguages "($lang)" \
    -AppleLocale "$locale" \
    -MarketingScreen "$screen" \
    -favoriteCategoryIds "$FAV_IDS" >/dev/null
  # Bump the wait for screens that chain auto-routing (sheet → push → reveal).
  # First-launch-in-language pays a cold-start cost (SwiftData + fonts re-init),
  # so we also bump home specifically — it's always the first screen captured.
  case "$screen" in
    review_session)    zzz 3.0 ;;
    post_prayer)       zzz 2.5 ;;
    context_detail)    zzz 2.5 ;;
    context_picker)    zzz 2.0 ;;
    memorize_filled)   zzz 2.0 ;;
    home)              zzz 3.5 ;;
    *)                 zzz 1.6 ;;
  esac
}

capture() {
  local lang="$1" screen="$2"
  mkdir -p "$RAW_DIR/$lang"
  xcrun simctl io "$SIM" screenshot --type=png "$RAW_DIR/$lang/$screen.png" 2>/dev/null
  echo "  ✓ $lang/$screen.png"
}

for lang in "${LANGS[@]}"; do
  locale="${LOCALES[$lang]}"
  echo "→ $lang ($locale)"
  for screen in "${SCREENS[@]}"; do
    launch "$lang" "$locale" "$screen"
    capture "$lang" "$screen"
  done
done

echo
echo "Done. Run: python3 scripts/make_screenshots.py"
