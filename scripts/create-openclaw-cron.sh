#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${TOPIC_MONITOR_CONFIG:-$ROOT/config/topic-monitor-config.json}"
CREATE=false
TARGET=""
CHANNEL=""
AGENT="project"
JOB_NAME=""

usage() {
  cat <<'EOF'
Usage:
  bash scripts/create-openclaw-cron.sh --to <dest> [--channel feishu] [--create]

Options:
  --to <dest>        Delivery target, e.g. user:ou_xxx or chat:oc_xxx
  --channel <name>   Delivery channel (default from config, fallback feishu)
  --agent <name>     Agent name for cron job (default: project)
  --name <text>      Override cron job name
  --create           Actually create the cron job
  --help             Show this help

By default this script prints the recommended openclaw cron add command.
Add --create to execute it.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --to)
      TARGET="${2:-}"
      shift 2
      ;;
    --channel)
      CHANNEL="${2:-}"
      shift 2
      ;;
    --agent)
      AGENT="${2:-}"
      shift 2
      ;;
    --name)
      JOB_NAME="${2:-}"
      shift 2
      ;;
    --create)
      CREATE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$CONFIG_FILE" ]; then
  echo "配置文件不存在: $CONFIG_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "缺少 jq" >&2
  exit 1
fi

TOPIC_NAME=$(jq -r '.topics[0].name // "未命名主题"' "$CONFIG_FILE")
SCHEDULE_TIME=$(jq -r '.schedule.time // "09:00"' "$CONFIG_FILE")
TZ_NAME=$(jq -r '.schedule.timezone // "Asia/Shanghai"' "$CONFIG_FILE")
CHANNEL=${CHANNEL:-$(jq -r '.delivery.channel // "feishu"' "$CONFIG_FILE")}
CONFIG_TARGET=$(jq -r '.delivery.target // empty' "$CONFIG_FILE")
TARGET=${TARGET:-$CONFIG_TARGET}

if [ -z "$TARGET" ]; then
  echo "缺少投递目标。请传 --to user:ou_xxx 或 --to chat:oc_xxx，或在 config/topic-monitor-config.json 里设置 delivery.target" >&2
  exit 1
fi

if ! [[ "$SCHEDULE_TIME" =~ ^([01][0-9]|2[0-3]):([0-5][0-9])$ ]]; then
  echo "schedule.time 格式非法: $SCHEDULE_TIME（应为 HH:MM）" >&2
  exit 1
fi

HOUR="${SCHEDULE_TIME%%:*}"
MINUTE="${SCHEDULE_TIME##*:}"
CRON_EXPR="${MINUTE} ${HOUR} * * *"
JOB_NAME=${JOB_NAME:-"topic-monitor:${TOPIC_NAME}"}

MESSAGE=$(cat <<EOF
Run the topic-monitor skill from ${ROOT}. Use ${CONFIG_FILE} as the config, execute TOPIC_MONITOR_CRON_RUN=1 scripts/topic-monitor-run.sh to generate today's digest, and reply with only the final markdown report for delivery. Do not ask whether to set scheduled publishing during cron runs.
EOF
)

CMD=(
  openclaw cron add
  --name "$JOB_NAME"
  --cron "$CRON_EXPR"
  --tz "$TZ_NAME"
  --session isolated
  --agent "$AGENT"
  --message "$MESSAGE"
  --channel "$CHANNEL"
  --to "$TARGET"
  --announce
  --light-context
  --timeout-seconds 180
)

if [ "$CREATE" = true ]; then
  "${CMD[@]}"
else
  printf '%q ' "${CMD[@]}"
  printf '\n'
fi
