# topic-monitor

一个把“先刷一轮网页、再手工整理”压成主题日报的独立工具包。

> 它就是一个可以单独获取、单独配置、单独运行的轻量工具包。

## 这个工具解决什么问题

如果你每天都要先看一轮外部信息，通常会重复做这些动作：
- 打开几个固定来源
- 搜主题关键词
- 点开详情页
- 排掉低价值页面
- 留下少量值得继续看的内容
- 再整理成一份当天可接手的结果

`topic-monitor` 接走的，就是这段重复劳动。

它不会替你做最终判断，但会先把：
- 搜
- 看
- 粗筛
- 整理

压成一份结构化日报，让你直接从“已整理结果”开始，而不是从噪音开始。

## 产品形态

`topic-monitor` 的对外形态是：**独立工具包**。

读者拿到后，最小包含这些文件：

```text
topic-monitor/
├── README.md
├── scripts/
│   └── topic-monitor-run.sh
├── config/
│   ├── topic-monitor-config.example.json
│   └── 字段说明.md
├── examples/
│   └── sample-report.md
└── output/
    └── .gitkeep
```

## 唯一主入口

唯一主入口：

```bash
bash scripts/topic-monitor-run.sh
```

这次重构后的口径只有这一条：
- 主入口脚本：`scripts/topic-monitor-run.sh`
- 配置入口：`config/topic-monitor-config.json`
- 输出目录：`output/`

不要再把它理解成多个脚本并列的系统。

## 最小依赖

运行前请准备：
- Bash
- `curl`
- `jq`
- Node.js 18+
- Tavily API Key（环境变量：`TAVILY_API_KEY`）

快速自检：

```bash
bash --version >/dev/null && curl --version >/dev/null && jq --version >/dev/null && node --version
```

## 3 步手动跑通

### 第一步：获取工具包

```bash
git clone https://gitee.com/woipanda/topic-monitor.git
cd topic-monitor
```

### 第二步：复制并修改配置

```bash
cp config/topic-monitor-config.example.json config/topic-monitor-config.json
```

然后编辑：
`config/topic-monitor-config.json`

最少先改这些字段：
- `topics[0].name`
- `topics[0].keywords`
- `topics[0].preferredDomains`
- `topics[0].blockedDomains`
- `output.finalItems`
- `output.watchItems`

再准备环境变量：

```bash
export TAVILY_API_KEY='你的 Tavily API Key'
```

### 第三步：运行并查看结果

```bash
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
ls -lh ./output
cat ./output/$(TZ=Asia/Shanghai date +%Y-%m-%d)-主题监控日报.md
```

## 配置文件怎么改

配置入口只有一个：

```text
config/topic-monitor-config.json
```

如果你想换主题，先改：
- `topics[0].name`：日报里展示的主题名
- `topics[0].keywords`：真正驱动搜索的关键词

如果你想调筛选口径，优先看：
- `preferredDomains`
- `blockedDomains`
- `output.finalItems`
- `output.watchItems`
- `output.minSelectedScore`
- `filters.excludeKeywords`

详细字段说明见：
- `config/字段说明.md`

## 输出结果长什么样

默认输出文件：

```text
output/YYYY-MM-DD-主题监控日报.md
```

输出内容会包含：
- 今日精选
- 观察池
- 每条的摘要
- 内容类型
- 业务价值
- 入选原因
- 建议动作
- 当日统计

示例见：
- `examples/sample-report.md`

## 它实际会做什么

你可以把它理解成 6 步：
1. 定主题
2. 搜结果
3. 抓详情
4. 压低价值页
5. 做精选 / 观察池分流
6. 写回日报

所以书里真正该写的，不是参数表，而是这 6 步怎样把“先刷一轮网页”压成“先看一份日报”。

## 适用边界

这个工具适合：
- 固定主题监控
- 每天 / 定时看一轮外部信息
- 先做一轮初筛，再由人继续判断

它不适合被写成：
- 万能情报系统
- 自动替人下战略结论的工具
- 完整知识管理系统

更准确的说法是：
**它先替你做一轮搜、看、筛、整理，但最后判断和后续动作仍然在人。**

## 书里怎么称呼它

建议统一写法：
- `topic-monitor 主题监控工具包`
- 或 `topic-monitor 独立工具包`

不建议再把它写成抽象能力模块或系统内部目录方案。

因为这节书稿要强调的是：
**读者拿到的是一个独立工具包，可以直接获取、配置、运行。**
