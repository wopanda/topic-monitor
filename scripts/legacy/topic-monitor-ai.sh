#!/bin/bash

# AI 驱动的主题监控系统
# 直接调用 AI 来搜索、分析和生成报告

set -e

CONFIG_FILE="/root/.openclaw/workspace/topic-monitor-config.json"
WORKSPACE="/root/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory/topic-reports"
TODAY=$(date '+%Y-%m-%d')
REPORT_FILE="$MEMORY_DIR/report-$TODAY.md"

# 创建目录
mkdir -p "$MEMORY_DIR"

# 检查配置
if [ ! -f "$CONFIG_FILE" ]; then
    echo "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

ENABLED=$(jq -r '.enabled' "$CONFIG_FILE")
if [ "$ENABLED" != "true" ]; then
    echo "主题监控已禁用"
    exit 0
fi

# 读取主题配置
TOPICS=$(jq -c '.topics[] | select(.enabled == true)' "$CONFIG_FILE")

if [ -z "$TOPICS" ]; then
    echo "没有启用的监控主题"
    exit 0
fi

echo "开始生成主题监控日报..."
echo "日期: $TODAY"
echo "配置文件: $CONFIG_FILE"
echo ""

# 生成 AI 提示词
cat > /tmp/ai-prompt.md << EOF
# 任务: 生成主题监控日报

## 配置信息
- 日期: $TODAY
- 配置文件: $CONFIG_FILE

## 执行步骤

### 1. 读取配置
首先读取配置文件，获取所有启用的主题和关键词。

### 2. 信息搜索
对每个主题，使用 WebSearch 工具搜索相关信息：
- 搜索最近 24 小时的内容
- 使用配置中的所有关键词
- 优先搜索: GitHub、技术博客、官方文档、社区讨论

### 3. 信息处理
- 去重: 相似度 >80% 的内容视为重复
- 筛选: 只保留高质量、有价值的信息
- 排序: 按相关性和时效性排序
- 限制: 最多保留 10 条

### 4. 生成报告
按以下格式生成 Markdown 报告:

\`\`\`markdown
# 📊 主题监控日报 - $TODAY

> 🤖 由 OpenClaw AI 自动生成

## 🎯 监控主题

{列出所有监控的主题名称}

---

## 📰 今日发现 ({数量} 条)

### 1. {信息标题}

**📝 摘要**: {用一句话概括核心内容}

**🔗 来源**: [{来源名称}]({完整URL})

**⏰ 时间**: {发布时间}

**🏷️ 标签**: #{相关标签1} #{相关标签2}

**💡 为什么重要**: {简短说明这条信息的价值}

---

### 2. {下一条信息...}

---

## 💡 今日洞察

{AI 分析今天发现的信息，总结出:}
- 主要趋势是什么？
- 有哪些新的应用场景？
- 社区在讨论什么热点？
- 有什么值得关注的技术动向？

## 📊 统计数据

- 🔍 搜索关键词: {数量} 个
- 📥 原始结果: {数量} 条
- 🔄 去重后: {数量} 条
- ✅ 最终筛选: {数量} 条
- ⭐ 平均质量分: {1-5 分}

## 🎯 明日建议

{基于今天的发现，建议明天重点关注什么}

---

*📅 生成时间: $(date '+%Y-%m-%d %H:%M:%S')*
*⚙️ 配置文件: topic-monitor-config.json*
*🤖 由 OpenClaw AI 自动生成*
\`\`\`

### 5. 保存报告
将生成的报告保存到: $REPORT_FILE

### 6. 推送摘要
生成一个简短版本（300 字以内），包含:
- 今日发现数量
- 最重要的 3 条信息标题
- 一句话洞察

然后通过企业微信推送。

## 特殊情况处理

### 如果没有找到相关信息:
生成一个说明报告:
\`\`\`markdown
# 📊 主题监控日报 - $TODAY

## ⚠️ 今日无新发现

在过去 24 小时内，没有找到与以下主题相关的新信息:
- {主题列表}

### 可能的原因:
1. 关键词设置过于具体
2. 该领域今天确实没有新动态
3. 搜索源覆盖不够

### 建议:
- 尝试使用更通用的关键词
- 扩大搜索时间范围到 48 小时
- 添加更多搜索源

---
*由 OpenClaw AI 自动生成*
\`\`\`

## 开始执行

现在请执行上述任务，生成今天的主题监控日报。
EOF

echo "AI 提示词已生成: /tmp/ai-prompt.md"
echo ""
echo "请 AI 处理并生成报告..."
echo "报告将保存到: $REPORT_FILE"
echo ""
echo "=== AI 提示词内容 ==="
cat /tmp/ai-prompt.md
echo ""
echo "=== 提示词结束 ==="

# 注意: 这个脚本需要在 OpenClaw 环境中运行
# AI 会读取这个提示词并执行任务

exit 0
