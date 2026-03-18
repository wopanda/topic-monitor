#!/bin/bash

# 主题监控脚本 - 自动抓取并生成日报
# 作者: OpenClaw AI
# 用途: 根据配置文件中的主题关键词，自动搜索相关信息并推送日报

set -e

# 配置文件路径
CONFIG_FILE="/root/.openclaw/workspace/topic-monitor-config.json"
WORKSPACE="/root/.openclaw/workspace"
MEMORY_DIR="/root/obsidian-vault/Input/TopicReports"
LOG_FILE="/root/.openclaw/logs/topic-monitor.log"

# 创建必要的目录
mkdir -p "$MEMORY_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========== 开始执行主题监控任务 =========="

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    log "错误: 配置文件不存在 $CONFIG_FILE"
    exit 1
fi

# 读取配置
ENABLED=$(jq -r '.enabled' "$CONFIG_FILE")
if [ "$ENABLED" != "true" ]; then
    log "主题监控已禁用，跳过执行"
    exit 0
fi

# 生成今日报告文件名
TODAY=$(date '+%Y-%m-%d')
REPORT_FILE="$MEMORY_DIR/$TODAY-主题监控日报.md"

log "开始生成日报: $REPORT_FILE"

# 调用 OpenClaw AI 生成报告
# 这里使用 openclaw 的 CLI 接口来调用 AI
cat > /tmp/topic-monitor-prompt.txt << 'EOF'
请根据配置文件 /root/.openclaw/workspace/topic-monitor-config.json 中的主题设置，执行以下任务：

1. 读取配置文件中的所有主题和关键词
2. 对每个启用的主题，搜索最近 24 小时内的相关信息
3. 去重并筛选出最有价值的 10 条信息
4. 生成结构化的日报，格式如下：

---
# 📊 主题监控日报 - {日期}

## 🎯 监控主题
- {主题名称}

## 📰 今日发现 ({数量} 条)

### 1. {标题}
**摘要**: {一句话概括}
**来源**: [{来源名称}]({URL})
**时间**: {发布时间}
**关键词**: #{标签1} #{标签2}

---

## 💡 今日洞察
{AI 分析这些信息的共同趋势或有价值的发现}

## 📈 统计
- 搜索关键词: {数量} 个
- 原始结果: {数量} 条
- 去重后: {数量} 条
- 最终筛选: {数量} 条

---
*由 OpenClaw AI 自动生成 | 配置文件: topic-monitor-config.json*
---

5. 将报告保存到: /root/obsidian-vault/Input/TopicReports/{日期}-主题监控日报.md
6. 通过企业微信推送报告摘要（前 3 条重点信息）

注意事项:
- 使用 WebSearch 工具搜索信息
- 相似度 >80% 的内容视为重复
- 优先选择来自 GitHub、技术博客、官方文档的信息
- 如果没有找到相关信息，说明原因并给出建议

开始执行任务。
EOF

# 使用 openclaw CLI 执行任务
# 注意: 这里假设 openclaw 有 CLI 接口，实际使用时需要根据你的环境调整
log "调用 AI 生成报告..."

# 方式 1: 如果有 openclaw CLI
# openclaw chat --file /tmp/topic-monitor-prompt.txt --output "$REPORT_FILE"

# 方式 2: 通过 API 调用（需要配置 API endpoint）
# curl -X POST http://localhost:18789/api/chat \
#   -H "Authorization: Bearer YOUR_TOKEN" \
#   -d @/tmp/topic-monitor-prompt.txt

# 方式 3: 直接写入任务队列，让 AI 异步处理
TASK_FILE="$WORKSPACE/.openclaw/tasks/topic-monitor-$(date +%s).task"
mkdir -p "$(dirname "$TASK_FILE")"
cp /tmp/topic-monitor-prompt.txt "$TASK_FILE"

log "任务已创建: $TASK_FILE"
log "AI 将在后台处理并生成报告"

# 清理临时文件
rm -f /tmp/topic-monitor-prompt.txt

log "========== 主题监控任务完成 =========="

exit 0
