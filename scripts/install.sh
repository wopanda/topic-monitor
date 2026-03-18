#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_CONFIG="$REPO_DIR/config/topic-monitor-config.json"

if [ ! -f "$TARGET_CONFIG" ]; then
  cp "$REPO_DIR/config/topic-monitor-config.example.json" "$TARGET_CONFIG"
  echo "已生成配置文件: $TARGET_CONFIG"
else
  echo "配置文件已存在: $TARGET_CONFIG"
fi

mkdir -p "$REPO_DIR/output"
echo "已准备输出目录: $REPO_DIR/output"

echo "下一步："
echo "1) 编辑 config/topic-monitor-config.json"
echo "2) export TAVILY_API_KEY='你的 Tavily API Key'"
echo "3) TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh"
