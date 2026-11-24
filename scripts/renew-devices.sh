#!/bin/bash
# Re-signs and reinstalls the iPhone app (with its embedded Watch app) using a free Apple ID.
# Free "Personal Team" provisioning profiles expire 7 days after they are issued. Reinstalling over
# the existing app before then keeps it launchable, and app data is preserved (never delete the app).
#
# Usage:
#   scripts/renew-devices.sh           # renew only if the last install is older than RENEW_AFTER_DAYS
#   scripts/renew-devices.sh --force   # renew now
#
# One-time setup: see docs/free-signing.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/scripts/signing.env"   # git-ignored; holds TEAM_ID and DEVICE
STATE="$HOME/Library/Application Support/MeetingRecorderRenew/last-install"
LOG_DIR="$HOME/Library/Logs/MeetingRecorderRenew"
RENEW_AFTER_DAYS="${RENEW_AFTER_DAYS:-5}"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

notify() {
    osascript -e "display notification \"$1\" with title \"บันทึกประชุม\"" >/dev/null 2>&1 || true
    echo "$(date '+%F %T') $1"
}

[[ -f "$CONFIG" ]] || { notify "ยังไม่ได้ตั้งค่า scripts/signing.env"; exit 1; }
# shellcheck source=/dev/null
source "$CONFIG"
: "${TEAM_ID:?TEAM_ID missing in signing.env}"
: "${DEVICE:?DEVICE missing in signing.env}"

mkdir -p "$(dirname "$STATE")" "$LOG_DIR"
LOG="$LOG_DIR/$(date +%F).log"

if [[ "${1:-}" != "--force" && -f "$STATE" ]]; then
    age_days=$(( ($(date +%s) - $(cat "$STATE")) / 86400 ))
    if (( age_days < RENEW_AFTER_DAYS )); then
        echo "Last install ${age_days} day(s) ago; nothing to do."
        exit 0
    fi
fi

if ! xcrun devicectl list devices 2>/dev/null | grep -F "$DEVICE" | grep -q "available"; then
    days_left=7
    [[ -f "$STATE" ]] && days_left=$(( 7 - ($(date +%s) - $(cat "$STATE")) / 86400 ))
    notify "ต่ออายุแอปไม่ได้: ไม่เจอ iPhone (เหลือ ~${days_left} วัน) ให้ iPhone ปลดล็อกและอยู่ Wi-Fi เดียวกับ Mac"
    exit 2
fi

cd "$ROOT"
xcodegen generate --quiet
BUILD="$ROOT/build/device"
if ! xcodebuild -project MeetingRecorder.xcodeproj -scheme MeetingRecorder \
        -destination 'generic/platform=iOS' -derivedDataPath "$BUILD" \
        -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" \
        build >"$LOG" 2>&1; then
    notify "ต่ออายุแอปไม่สำเร็จ: build ผิดพลาด ดู log ที่ $LOG"
    exit 3
fi

APP="$BUILD/Build/Products/Debug-iphoneos/MeetingRecorder.app"
if ! xcrun devicectl device install app --device "$DEVICE" "$APP" >>"$LOG" 2>&1; then
    notify "ต่ออายุแอปไม่สำเร็จ: ติดตั้งลง iPhone ไม่ได้ ดู log ที่ $LOG"
    exit 4
fi

date +%s >"$STATE"
expiry=$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null \
    | plutil -extract ExpirationDate raw -o - - 2>/dev/null || echo "unknown")
notify "ต่ออายุแอปแล้ว ใช้ได้ถึง ${expiry}"
