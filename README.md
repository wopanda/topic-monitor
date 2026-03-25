# topic-monitor

每天围绕一个固定主题，自动帮你整理出一份**简洁版日报**。

它适合把这类重复动作接过去：
- 搜主题
- 看结果
- 过滤低价值页
- 留下今天最值得看的内容
- 顺手给一句简短判断

最终产物不是一堆原始链接，而是一份可以直接读的 Markdown 日报。

---

## 你会得到什么

默认输出一份简洁版日报，通常只有三块：

### 1. 今天最值得看
列出今天最值得点开的 3~5 条内容。

### 2. 今天看到的变化
用一句话概括今天这批结果的大致方向。

### 3. 还可以顺手看看
把暂时没进主列表、但值得留意的内容放在这里。

---

## 适合谁用

适合：
- 想持续跟一个主题的人
- 想每天看一份轻量整理结果的人
- 想先做一轮初筛，再决定要不要深挖的人

不适合：
- 期待它直接替你下最终结论
- 把它当成完整情报系统
- 想让它代替长期知识管理

---

## 3 步开始

### 第 1 步：克隆仓库

```bash
git clone https://gitee.com/woipanda/topic-monitor.git
cd topic-monitor
```

### 第 2 步：初始化并安装依赖

```bash
bash scripts/install.sh
pip3 install -r requirements.txt
```

### 第 3 步：运行

```bash
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
cat ./output/$(TZ=Asia/Shanghai date +%Y-%m-%d)-主题监控日报.md
```

---

## 最少只要改这两个地方

配置文件：

```text
config/topic-monitor-config.json
```

大多数读者最少只需要改：

### `topics[0].name`
日报里显示的主题名。

### `topics[0].keywords`
真正驱动搜索的关键词数组。

例如：

```json
{
  "topics": [
    {
      "name": "OpenClaw 使用案例",
      "keywords": [
        "OpenClaw 用例",
        "OpenClaw 实践",
        "OpenClaw 应用场景"
      ]
    }
  ]
}
```

如果你只是第一次试跑，先只改这两个字段就够了。

---

## 默认就是自动模式

读者默认只需要理解一件事：

**直接运行就行。**

系统内部会自动处理：
- 有 `TAVILY_API_KEY` → 自动增强搜索效果
- 没有 `TAVILY_API_KEY` → 自动退回保底搜索

也就是说：
- 有 key，结果通常会更稳、更完整
- 没有 key，也不会直接跑不起来

### 如果你有 Tavily key（可选）

```bash
export TAVILY_API_KEY='你的 Tavily API Key'
```

不提供也可以直接运行。

---

## 跑出来大概长什么样

默认输出会接近这样：

```markdown
# 主题监控日报 | 2026-03-25

## 今天关注什么
- OpenClaw 使用案例

## 今天最值得看
1. 某个 GitHub 仓库
   - 值得看：这是一手仓库，后面真要深入时可以先从这里开始。
   - 链接：https://...

2. 某篇上手指南
   - 值得看：这条适合快速上手，能帮你少走一点弯路。
   - 链接：https://...

## 今天看到的变化
- 今天这批结果里，既有一手仓库，也有可直接借鉴的用例内容。

## 还可以顺手看看
- 某条内容（先留着观察）
- 某条内容（同域内容已折叠）
```

---

## 输出位置

实际运行后，日报会写到：

```text
output/YYYY-MM-DD-主题监控日报.md
```

示例文件：

```text
examples/sample-report.md
```

---

## 怎么确认它已经跑通

```bash
TODAY=$(TZ=Asia/Shanghai date +%Y-%m-%d)
[ -s "./output/${TODAY}-主题监控日报.md" ] && echo "输出有内容 ✅" || echo "输出为空 ❌"
grep -n "今天最值得看\|今天看到的变化\|还可以顺手看看" "./output/${TODAY}-主题监控日报.md"
```

---

## 进阶可调项（可选）

如果你已经跑通，再考虑改这些：
- `topics[0].preferredDomains`：希望优先看的站点
- `topics[0].blockedDomains`：明确不想看的站点
- `output.finalItems`：主列表条数
- `output.watchItems`：补充列表条数

如果只是第一次上手，可以先不用动这些。

---

## 依赖环境

需要本地具备：
- Python 3
- Node.js 18+
- `jq`

Python 依赖通过下面这条安装：

```bash
pip3 install -r requirements.txt
```

---

## 安全提醒

- `TAVILY_API_KEY` 只通过环境变量注入，不要写进仓库
- 不要提交 `.env`、本地配置副本、运行日志或临时输出
- 公开仓库前，先确认没有真实 key、私人主题或历史输出残留

---

## 这是一个什么定位的工具

你可以把它理解成：

**一个“主题监控 + 线索初筛 + 简洁日报输出”的小工具。**

它的工作不是替你做最终判断，而是先把今天值得看的东西整理出来，让你更快进入下一步。
