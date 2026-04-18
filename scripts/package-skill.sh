#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp-package/topic-monitor"
OUT_DIR="$ROOT/dist"
PACKAGE_SCRIPT="/root/.openclaw/skills/skill-creator/scripts/package_skill.py"

rm -rf "$ROOT/.tmp-package"
mkdir -p "$TMP/scripts" "$TMP/config" "$TMP/examples" "$TMP/references" "$TMP/output" "$OUT_DIR"
cp "$ROOT/SKILL.md" "$TMP/SKILL.md"
cp "$ROOT/README.md" "$TMP/README.md"
cp "$ROOT/LICENSE" "$TMP/LICENSE"
cp "$ROOT/requirements.txt" "$TMP/requirements.txt"
cp "$ROOT/scripts/install.sh" "$TMP/scripts/install.sh"
cp "$ROOT/scripts/search_bocha.py" "$TMP/scripts/search_bocha.py"
cp "$ROOT/scripts/topic-monitor-render.js" "$TMP/scripts/topic-monitor-render.js"
cp "$ROOT/scripts/topic-monitor-run.sh" "$TMP/scripts/topic-monitor-run.sh"
cp "$ROOT/scripts/create-openclaw-cron.sh" "$TMP/scripts/create-openclaw-cron.sh"
cp "$ROOT/scripts/verify-skill.sh" "$TMP/scripts/verify-skill.sh"
cp "$ROOT/config/topic-monitor-config.example.json" "$TMP/config/topic-monitor-config.example.json"
cp "$ROOT/config/字段说明.md" "$TMP/config/字段说明.md"
cp "$ROOT/examples/sample-report.md" "$TMP/examples/sample-report.md"
cp "$ROOT/references/scheduled-delivery.md" "$TMP/references/scheduled-delivery.md"
cp "$ROOT/references/natural-interaction.md" "$TMP/references/natural-interaction.md"
cp "$ROOT/output/.gitkeep" "$TMP/output/.gitkeep"

PYTHONPATH="/root/.openclaw/skills/skill-creator" python3 "$PACKAGE_SCRIPT" "$TMP" "$OUT_DIR"

echo "✅ packaged: $OUT_DIR/topic-monitor.skill"
