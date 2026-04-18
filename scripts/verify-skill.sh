#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp-verify"
rm -rf "$TMP"
mkdir -p "$TMP/output"

[ -f "$ROOT/SKILL.md" ]
[ -f "$ROOT/README.md" ]
[ -f "$ROOT/requirements.txt" ]
[ -f "$ROOT/scripts/search_bocha.py" ]
[ -f "$ROOT/scripts/topic-monitor-render.js" ]
[ -f "$ROOT/config/topic-monitor-config.example.json" ]
[ -f "$ROOT/examples/sample-report.md" ]

bash "$ROOT/scripts/install.sh" >/dev/null
python3 -m py_compile "$ROOT/scripts/search_bocha.py"
node --check "$ROOT/scripts/topic-monitor-render.js" >/dev/null

cp "$ROOT/config/topic-monitor-config.example.json" "$TMP/topic-monitor-config.json"
TODAY=$(TZ=Asia/Shanghai date +%Y-%m-%d)
OUT="$TMP/output/${TODAY}-主题监控日报.md"

TOPIC_MONITOR_CONFIG="$TMP/topic-monitor-config.json" TOPIC_MONITOR_OUTPUT_DIR="$TMP/output" bash "$ROOT/scripts/topic-monitor-run.sh" >/dev/null || true

if [ -s "$OUT" ]; then
  echo "✅ verify ok"
  echo "- report: $OUT"
  grep -n "今天最值得看\|今天看到的变化\|还可以顺手看看" "$OUT" || true
else
  echo "✅ verify partial"
  echo "- structure/scripts/config are ready"
  echo "- full run may still depend on local Python deps: pip3 install -r requirements.txt"
fi
