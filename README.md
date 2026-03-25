# topic-monitor

一个**符合 Skill 规范**的主题监控 Skill，用来把固定主题的外部信息扫描结果整理成结构化日报。

## 这次重构后的核心变化

这版不再强依赖 Tavily。

默认逻辑改成：
- **有 `TAVILY_API_KEY`** → 自动走 **Tavily + China 搜索融合**
- **没有 `TAVILY_API_KEY`** → 自动退回 **China 搜索方案**

也就是说：
- 用户如果给了 Tavily key，结果会更稳、更广
- 用户如果没给，也不会直接卡死，而是还能继续跑国内搜索链路

## 这个 Skill 做什么

它帮你把这段重复劳动接过去：
- 搜主题
- 看结果
- 抓详情
- 压低价值页
- 做精选 / 观察池分流
- 写回日报

最终产物是一份 markdown 日报，而不是一堆原始链接。

## 仓库结构

```text
topic-monitor/
├── README.md
├── SKILL.md
├── requirements.txt
├── scripts/
│   ├── install.sh
│   ├── search.py
│   ├── search_router.py
│   ├── topic-monitor-render.js
│   ├── topic-monitor-run.sh
│   ├── verify-skill.sh
│   └── package-skill.sh
├── config/
│   ├── topic-monitor-config.example.json
│   └── 字段说明.md
├── examples/
│   └── sample-report.md
└── output/
    └── .gitkeep
```

## 主入口

唯一主入口：

```bash
bash scripts/topic-monitor-run.sh
```

初始化脚本：

```bash
bash scripts/install.sh
```

## 依赖

- Bash
- `jq`
- Python 3
- Node.js 18+
- Python 包：`requests`、`beautifulsoup4`
- 可选：`TAVILY_API_KEY`

快速自检：

```bash
bash --version >/dev/null && jq --version >/dev/null && python3 --version >/dev/null && node --version >/dev/null
```

## 安装方式

### 方式 A：把仓库链接发给小龙虾

你可以直接这样说：

```text
帮我安装这个 skill：https://gitee.com/woipanda/topic-monitor
```

### 方式 B：手动安装 / 运行

```bash
git clone https://gitee.com/woipanda/topic-monitor.git
cd topic-monitor
bash scripts/install.sh
```

然后安装 Python 依赖：

```bash
pip3 install -r requirements.txt
```

## 配置

唯一配置入口：

```text
config/topic-monitor-config.json
```

### 默认就是自动模式

读者默认只需要理解一件事：
- **直接用默认模式就行**

系统内部会自动处理：
- 有 `TAVILY_API_KEY` → 自动增强搜索效果
- 没有 `TAVILY_API_KEY` → 自动退回保底搜索

通常不建议读者自己改 `search.provider / route / mode`。这些更适合开发者调试。

常改字段：
- `topics[0].name`
- `topics[0].keywords`
- `topics[0].preferredDomains`
- `topics[0].blockedDomains`
- `output.finalItems`
- `output.watchItems`

## Tavily 是可选的

如果你有 Tavily key：

```bash
export TAVILY_API_KEY='你的 Tavily API Key'
```

如果没有，也可以直接运行，程序会自动退回 China 搜索，不会因为缺 key 直接退出。

## 运行并查看结果

```bash
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
cat ./output/$(TZ=Asia/Shanghai date +%Y-%m-%d)-主题监控日报.md
```

## 输出长什么样

默认会输出一份**简洁版日报**，通常只包含：
- 今天最值得看
- 一句话判断
- 还可以再看看

调试信息默认不展示，只有在开发调试时才建议开启。

## 示例输出

示例文件：

```text
examples/sample-report.md
```

实际运行后输出到：

```text
output/YYYY-MM-DD-主题监控日报.md
```

## 验收方式

```bash
TODAY=$(TZ=Asia/Shanghai date +%Y-%m-%d)
[ -s "./output/${TODAY}-主题监控日报.md" ] && echo "输出有内容 ✅" || echo "输出为空 ❌"
grep -n "今日精选\|观察池\|今日判断\|使用搜索源\|路由计划" "./output/${TODAY}-主题监控日报.md"
```

## 安全约束

- `TAVILY_API_KEY` 只允许通过环境变量注入，不要写进仓库
- 不要提交 `.env`、本地配置副本、运行日志或临时输出
- 公开仓库前，先再次检查：没有真实 key、没有私人监控主题、没有历史输出残留

## 适用范围

适合：
- 固定主题监控
- 定时生成日报
- 国内搜索优先的主题观察
- 有 key / 没 key 都想尽量跑起来

不适合：
- 替人直接下最终结论
- 充当万能情报系统
- 代替完整知识管理系统
