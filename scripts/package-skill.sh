#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp-package/topic-monitor"
OUT_DIR="$ROOT/dist"
PACKAGE_SCRIPT="/root/.openclaw/extensions/wecom/node_modules/openclaw/skills/skill-creator/scripts/package_skill.py"

rm -rf "$ROOT/.tmp-package"
mkdir -p "$TMP/scripts" "$TMP/config" "$TMP/examples" "$TMP/output" "$OUT_DIR"
cp "$ROOT/SKILL.md" "$TMP/SKILL.md"
cp "$ROOT/README.md" "$TMP/README.md"
cp "$ROOT/scripts/install.sh" "$TMP/scripts/install.sh"
cp "$ROOT/scripts/topic-monitor-run.sh" "$TMP/scripts/topic-monitor-run.sh"
cp "$ROOT/config/topic-monitor-config.example.json" "$TMP/config/topic-monitor-config.example.json"
cp "$ROOT/config/字段说明.md" "$TMP/config/字段说明.md"
cp "$ROOT/examples/sample-report.md" "$TMP/examples/sample-report.md"
cp "$ROOT/output/.gitkeep" "$TMP/output/.gitkeep"

python3 "$PACKAGE_SCRIPT" "$TMP" "$OUT_DIR"

echo "✅ packaged: $OUT_DIR/topic-monitor.skill"
