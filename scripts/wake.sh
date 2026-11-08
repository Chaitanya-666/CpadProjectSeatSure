#!/usr/bin/env bash
# Wake the free-tier servers before a demo.
#
# One request to /api/health wakes both:
#   - Render starts the sleeping web service on the first HTTP request
#     (free tier sleeps after 15 idle minutes, start-up takes 30-60 s),
#   - the health route runs SELECT now(), which wakes the Neon compute
#     (Neon suspends after ~5 idle minutes, wake-up takes about a second).
#
# Usage: scripts/wake.sh [base-url] [max-seconds]
#   defaults: https://seatsure-9hn0.onrender.com, 180
# Exit code 0 = API up and DB up, 1 = gave up, 2 = API up but DB down.

set -u

BASE="${1:-https://seatsure-9hn0.onrender.com}"
MAX="${2:-180}"
URL="${BASE%/}/api/health"

start=$(date +%s)
try=0
echo "Waking $URL (giving up after ${MAX}s)"

while :; do
  try=$((try + 1))
  elapsed=$(( $(date +%s) - start ))
  left=$(( MAX - elapsed ))
  if (( left <= 0 )); then
    echo "Gave up after ${elapsed}s and $((try - 1)) tries. Check the Render dashboard (Events + Logs)."
    echo "If Logs show nothing for the last hour, the instance is stuck: Manual Deploy > Deploy latest commit"
    echo "(a plain Restart did not help on 2026-11-08; a redeploy of the same commit fixed it in ~4 min)."
    command -v notify-send >/dev/null && notify-send "SeatSure" "Server did not wake after ${elapsed}s"
    exit 1
  fi

  # Render holds the first request open while the service boots, so give
  # each try a long timeout instead of hammering it with short ones.
  per_try=$(( left < 75 ? left : 75 ))
  body=$(curl -sS -m "$per_try" -w '\n%{http_code}' "$URL" 2>&1)
  code=${body##*$'\n'}
  body=${body%$'\n'*}
  body=${body//$'\n'/ }
  elapsed=$(( $(date +%s) - start ))

  if [[ "$code" == "200" && "$body" == *'"db":"up"'* ]]; then
    echo "UP after ${elapsed}s (try $try): $body"
    command -v notify-send >/dev/null && notify-send "SeatSure" "Server and DB are up (${elapsed}s)"
    exit 0
  elif [[ "$code" == "503" && "$body" == *'"db":"down"'* ]]; then
    echo "API is up but the database is DOWN after ${elapsed}s: $body"
    command -v notify-send >/dev/null && notify-send "SeatSure" "API up, database DOWN"
    exit 2
  fi

  echo "  try $try at ${elapsed}s: HTTP ${code:-none} ${body:0:120}"
  sleep 5
done
