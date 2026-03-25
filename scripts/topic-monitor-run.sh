#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${TOPIC_MONITOR_CONFIG:-$REPO_DIR/config/topic-monitor-config.json}"
OUTPUT_DIR="${TOPIC_MONITOR_OUTPUT_DIR:-$REPO_DIR/output}"
TZ_NAME="${TOPIC_MONITOR_TZ:-Asia/Shanghai}"
TODAY=$(TZ="$TZ_NAME" date '+%Y-%m-%d')
OUT_FILE="$OUTPUT_DIR/${TODAY}-主题监控日报.md"
TMP_JSON="/tmp/topic-monitor-search-${TODAY}.json"
trap 'rm -f "$TMP_JSON"' EXIT

mkdir -p "$OUTPUT_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "配置文件不存在: $CONFIG_FILE"
  exit 1
fi

ENABLED=$(jq -r '.enabled // true' "$CONFIG_FILE")
if [ "$ENABLED" != "true" ]; then
  echo "主题监控已禁用"
  exit 0
fi

TOPIC_NAME=$(jq -r '.topics[0].name // "未命名主题"' "$CONFIG_FILE")
KEYWORDS=$(jq -r '.topics[0].keywords[]?' "$CONFIG_FILE" | paste -sd ' ' -)
KEYWORD_COUNT=$(jq -r '(.topics[0].keywords // []) | length' "$CONFIG_FILE")
RAW_PER_KEYWORD=$(jq -r '.output.rawPerKeyword // 4' "$CONFIG_FILE")
MAX_ITEMS=$(jq -r '.output.maxItems // 12' "$CONFIG_FILE")
FINAL_ITEMS=$(jq -r '.output.finalItems // 5' "$CONFIG_FILE")
WATCH_ITEMS=$(jq -r '.output.watchItems // 3' "$CONFIG_FILE")
MIN_SELECTED_SCORE=$(jq -r '.output.minSelectedScore // 5' "$CONFIG_FILE")
MIN_SELECTED_ITEMS=$(jq -r '.output.minSelectedItems // 3' "$CONFIG_FILE")
LOOKBACK_DAYS=$(jq -r '.filters.lookbackDays // 3' "$CONFIG_FILE")
EXCLUDE_JSON=$(jq -c '.filters.excludeKeywords // []' "$CONFIG_FILE")
PREFERRED_DOMAINS_JSON=$(jq -c '.topics[0].preferredDomains // []' "$CONFIG_FILE")
BLOCKED_DOMAINS_JSON=$(jq -c '.topics[0].blockedDomains // []' "$CONFIG_FILE")
TOPIC_PROFILE_JSON=$(jq -c '.topics[0].profile // {}' "$CONFIG_FILE")
SEARCH_PROVIDER=$(jq -r '.search.provider // "auto"' "$CONFIG_FILE")
SEARCH_ROUTE=$(jq -r '.search.route // "auto"' "$CONFIG_FILE")
SEARCH_MODE=$(jq -r '.search.mode // "hybrid"' "$CONFIG_FILE")
TOTAL_RESULTS=$(( KEYWORD_COUNT * RAW_PER_KEYWORD ))
if [ "$TOTAL_RESULTS" -lt "$MAX_ITEMS" ]; then
  MAX_RESULTS="$TOTAL_RESULTS"
else
  MAX_RESULTS="$MAX_ITEMS"
fi

if [ -z "${KEYWORDS:-}" ] || [ "$KEYWORD_COUNT" -eq 0 ]; then
  echo "未配置关键词"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "缺少 python3"
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "缺少 node"
  exit 1
fi

echo "主题: $TOPIC_NAME"
echo "关键词: $KEYWORDS"
echo "搜索策略: provider=$SEARCH_PROVIDER route=$SEARCH_ROUTE mode=$SEARCH_MODE"

run_auto_or_hybrid() {
  python3 "$REPO_DIR/scripts/search_router.py" "$KEYWORDS" \
    --route "$SEARCH_ROUTE" \
    --mode "$SEARCH_MODE" \
    --count "$MAX_RESULTS" \
    > "$TMP_JSON"
}

run_china_only() {
  python3 "$REPO_DIR/scripts/search.py" "$KEYWORDS" \
    --engine auto \
    --mode parallel \
    --count "$MAX_RESULTS" \
    > "$TMP_JSON"
}

run_tavily_only() {
  if [ -z "${TAVILY_API_KEY:-}" ]; then
    echo "provider=tavily 但当前缺少 TAVILY_API_KEY"
    exit 1
  fi
  python3 "$REPO_DIR/scripts/search_router.py" "$KEYWORDS" \
    --route global-first \
    --mode fallback \
    --count "$MAX_RESULTS" \
    > "$TMP_JSON"
}

case "$SEARCH_PROVIDER" in
  auto)
    run_auto_or_hybrid
    ;;
  hybrid)
    run_auto_or_hybrid
    ;;
  china)
    run_china_only
    ;;
  tavily)
    run_tavily_only
    ;;
  *)
    echo "不支持的 search.provider: $SEARCH_PROVIDER"
    exit 1
    ;;
esac

if ! jq -e 'type == "array" or (type == "object" and (.results? | type == "array"))' "$TMP_JSON" >/dev/null 2>&1; then
  echo "搜索结果格式异常"
  exit 1
fi

RAW_COUNT=$(jq -r 'if type == "array" then length else (.results | length) end' "$TMP_JSON")
USED_PROVIDER=$(jq -r 'if type == "array" then "china" else (.used_provider // "unknown") end' "$TMP_JSON")
RESOLVED_ROUTE=$(jq -r 'if type == "array" then "china-only" else ((.resolved_route // []) | join(" -> ")) end' "$TMP_JSON")
ATTEMPTS_SUMMARY=$(jq -r 'if type == "array" then "china:ok" else ((.attempts // []) | map(if .ok then (.provider + ":ok:" + ((.result_count // 0)|tostring)) else (.provider + ":fail:" + (.reason // "unknown")) end) | join(" | ")) end' "$TMP_JSON")

if [ "$RAW_COUNT" -eq 0 ]; then
  cat > "$OUT_FILE" <<EOF2
# 📊 主题监控日报 - ${TODAY}

## ⚠️ 今日无新发现

这次搜索没有拿到可用结果。

### 搜索执行信息
- provider: ${SEARCH_PROVIDER}
- used_provider: ${USED_PROVIDER}
- resolved_route: ${RESOLVED_ROUTE}
- attempts: ${ATTEMPTS_SUMMARY}

### 建议
- 检查关键词是否过窄
- 如需全球结果，可补充 TAVILY_API_KEY
- 如需国内结果优先，可将 search.provider 改为 china

---
*📅 生成时间: $(TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S') (${TZ_NAME})*
*⚙️ 配置文件: $(basename "$CONFIG_FILE")*
EOF2
  echo "报告已生成: $OUT_FILE"
  exit 0
fi

echo "搜索完成: raw=$RAW_COUNT used_provider=$USED_PROVIDER"
echo "尝试记录: $ATTEMPTS_SUMMARY"
echo "抓取链接详情并生成日报..."

node "$REPO_DIR/scripts/topic-monitor-render.js" \
  "$TMP_JSON" \
  "$OUT_FILE" \
  "$TODAY" \
  "$TOPIC_NAME" \
  "$KEYWORD_COUNT" \
  "$RAW_COUNT" \
  "$FINAL_ITEMS" \
  "$WATCH_ITEMS" \
  "$LOOKBACK_DAYS" \
  "$EXCLUDE_JSON" \
  "$OUTPUT_DIR" \
  "$MIN_SELECTED_SCORE" \
  "$MIN_SELECTED_ITEMS" \
  "$PREFERRED_DOMAINS_JSON" \
  "$BLOCKED_DOMAINS_JSON" \
  "$TOPIC_PROFILE_JSON"

echo "报告已生成: $OUT_FILE"
cat "$OUT_FILE"
