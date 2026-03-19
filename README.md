# topic-monitor

一个**符合 Skill 规范**的主题监控 Skill，用来把固定主题的外部信息扫描结果整理成结构化日报。

## 这个 Skill 做什么

它接走的是这段重复劳动：
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
├── scripts/
│   ├── install.sh
│   └── topic-monitor-run.sh
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
- `curl`
- `jq`
- Node.js 18+
- Tavily API Key（环境变量：`TAVILY_API_KEY`）

快速自检：

```bash
bash --version >/dev/null && curl --version >/dev/null && jq --version >/dev/null && node --version
```

## 3 步安装 / 运行

### 1. 获取代码

```bash
git clone https://gitee.com/woipanda/topic-monitor.git
cd topic-monitor
```

### 2. 初始化并配置

```bash
bash scripts/install.sh
```

然后编辑：

```text
config/topic-monitor-config.json
```

并准备环境变量：

```bash
export TAVILY_API_KEY='请在本地终端注入，不要写进仓库或截图'
```

### 3. 运行并查看结果

```bash
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
cat ./output/$(TZ=Asia/Shanghai date +%Y-%m-%d)-主题监控日报.md
```

## 配置入口

唯一配置入口：

```text
config/topic-monitor-config.json
```

常改字段：
- `topics[0].name`
- `topics[0].keywords`
- `topics[0].preferredDomains`
- `topics[0].blockedDomains`
- `output.finalItems`
- `output.watchItems`

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
grep -n "今日精选\|观察池\|今日判断" "./output/${TODAY}-主题监控日报.md"
```

## 安全约束

- `TAVILY_API_KEY` 只允许通过环境变量注入，不要写进仓库
- 不要提交 `.env`、本地配置副本、运行日志或临时输出
- 运行脚本时，API Key 不应直接拼进命令行参数展示
- 公开仓库前，先再次检查：没有真实 key、没有私人监控主题、没有历史输出残留

## 边界

适合：
- 固定主题监控
- 定时生成日报
- 先做一轮初筛，再由人继续判断

不适合：
- 替人直接下最终结论
- 充当万能情报系统
- 代替完整知识管理系统
