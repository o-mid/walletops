#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/mobile"
OUT="$ROOT/demos"
SHOTS="$OUT/screenshots"
RECORDINGS="$OUT/recordings"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
VIDEO="$OUT/walletops-demo-walkthrough.mp4"
SAVED_VIDEO="$RECORDINGS/walletops-demo-$STAMP.mp4"
SAVED_SHOTS="$RECORDINGS/screenshots-$STAMP"
API_BASE="${API_BASE:-http://127.0.0.1:8080}"

mkdir -p "$SHOTS" "$RECORDINGS"
rm -f "$SHOTS"/*.png
rm -f "$VIDEO"

echo "Checking API at $API_BASE"
curl -fsS "$API_BASE/v1/health" >/dev/null

echo "Booting iOS Simulator if needed"
open -a Simulator || true
sleep 3

DEVICE_ID="$(xcrun simctl list devices booted | awk -F '[()]' '/iPhone/{print $2; exit}')"
if [[ -z "${DEVICE_ID:-}" ]]; then
  (cd "$MOBILE" && fvm flutter emulators --launch apple_ios_simulator)
  sleep 10
  DEVICE_ID="$(xcrun simctl list devices booted | awk -F '[()]' '/iPhone/{print $2; exit}')"
fi
echo "Using simulator $DEVICE_ID"

echo "Starting screen recording → $VIDEO"
xcrun simctl io "$DEVICE_ID" recordVideo --codec=h264 "$VIDEO" &
REC_PID=$!
cleanup() {
  if kill -0 "$REC_PID" 2>/dev/null; then
    kill -INT "$REC_PID" 2>/dev/null || true
    wait "$REC_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

cd "$MOBILE"
fvm flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/demo_walkthrough_test.dart \
  -d "$DEVICE_ID" \
  --dart-define=API_BASE="$API_BASE"

cleanup
trap - EXIT

mkdir -p "$SAVED_SHOTS"
cp -f "$SHOTS"/*.png "$SAVED_SHOTS/" 2>/dev/null || true
cp -f "$VIDEO" "$SAVED_VIDEO"
ln -sfn "$(basename "$SAVED_VIDEO")" "$RECORDINGS/latest.mp4"
ln -sfn "$(basename "$SAVED_SHOTS")" "$RECORDINGS/latest-screenshots"

echo "Done."
echo "Latest screenshots: $SHOTS"
ls -la "$SHOTS" || true
echo "Latest recording:   $VIDEO"
ls -la "$VIDEO" || true
echo "Saved recording:    $SAVED_VIDEO"
echo "Saved screenshots:  $SAVED_SHOTS"
ls -la "$RECORDINGS" || true
