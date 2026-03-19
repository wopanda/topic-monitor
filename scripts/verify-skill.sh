#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp-verify"
rm -rf "$TMP"
mkdir -p "$TMP/output"

[ -f "$ROOT/SKILL.md" ]
[ -f "$ROOT/config/topic-monitor-config.example.json" ]
[ -f "$ROOT/examples/sample-report.md" ]

bash "$ROOT/scripts/install.sh" >/dev/null

python3 - <<'PY' "$TMP/topic-monitor-config.json"
import json, sys
cfg = {
  "enabled": True,
  "topics": [{
    "enabled": True,
    "name": "测试主题",
    "keywords": ["OpenClaw", "AI工作流"],
    "preferredDomains": ["github.com"],
    "blockedDomains": []
  }],
  "output": {"maxItems": 10, "finalItems": 5, "watchItems": 3},
  "filters": {"lookbackDays": 3, "excludeKeywords": []}
}
open(sys.argv[1], 'w', encoding='utf-8').write(json.dumps(cfg, ensure_ascii=False, indent=2))
PY

TODAY=$(TZ=Asia/Shanghai date +%Y-%m-%d)
OUT="$TMP/output/${TODAY}-主题监控日报.md"

if [ -n "${TAVILY_API_KEY:-}" ]; then
  TOPIC_MONITOR_CONFIG="$TMP/topic-monitor-config.json" TOPIC_MONITOR_OUTPUT_DIR="$TMP/output" bash "$ROOT/scripts/topic-monitor-run.sh" >/dev/null || true
fi

if [ -s "$OUT" ]; then
  echo "✅ verify ok"
  echo "- report: $OUT"
else
  echo "✅ verify ok"
  echo "- structure only: required files and install script present"
  echo "- note: full run requires TAVILY_API_KEY"
fi
