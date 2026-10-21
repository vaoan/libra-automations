#!/usr/bin/env bash
# DEV ONLY: render the fake receipts used by test-order.sh (needs Google Chrome).
#   tests/fixtures/receipt-match.png    — matches the test order (50.000, TEST-123456)
#   tests/fixtures/receipt-mismatch.png — wrong amount (30.000)
set -euo pipefail
cd "$(dirname "$0")/.."

chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

render() {
  local name=$1 amount=$2 reference=$3
  sed -e "s/{{AMOUNT}}/$amount/" -e "s/{{REFERENCE}}/$reference/" -e "s/{{DATE}}/21 oct 2026, 10:42 a. m./" \
    tests/fixtures/receipt.html > "$tmp/$name.html"
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=460,520 \
    --screenshot="$PWD/tests/fixtures/$name.png" "file://$tmp/$name.html" >/dev/null 2>&1
  echo "tests/fixtures/$name.png"
}

render receipt-match 50.000 TEST-123456
render receipt-mismatch 30.000 TEST-123456
