# topic-monitor

一个把“先刷一轮网页、再手工整理”压成主题日报的独立工具包。

> 对读者表述时，统一把它当成**独立工具包**理解。
> 对技术交付层，它已经补齐为**符合 Skill 规范的能力包**，这样后续才方便安装、复用、验证。

## 这节到底要证明什么能力

这节要证明的不是“会搜索”，而是：
**可以把每天先看一轮、先筛一轮、先整理一轮外部信息的重复劳动，稳定压成一份日报。**

所以 `topic-monitor` 的角色不是万能情报系统，而是：
- 先搜
- 先看
- 先粗筛
- 先整理
- 再把结果回传给人

## 为什么它应该以能力包交付，而不是只给脚本

如果只给一份裸脚本，会有 3 个问题：
1. 读者不知道主入口到底是谁
2. 配置入口、输出结果、验收方式都不稳定
3. 后续团队也没法把它当成一个可复用能力继续验证和沉淀

所以这次交付不是“一个散脚本”，而是一个带：
- 主入口
- 配置样例
- 使用说明
- 示例输出
- 验收方式

的能力包。

但书里对外还是建议写成：
- `topic-monitor 主题监控工具包`
- `topic-monitor 独立工具包`

## 产品形态

读者拿到后，最小包含这些文件：

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

## 唯一主入口

唯一主入口：

```bash
bash scripts/topic-monitor-run.sh
```

当前稳定口径只有这一条：
- 主入口脚本：`scripts/topic-monitor-run.sh`
- 配置入口：`config/topic-monitor-config.json`
- 输出目录：`output/`

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

## 3 步安装 / 运行

### 第一步：获取工具包

```bash
git clone https://gitee.com/woipanda/topic-monitor.git
cd topic-monitor
```

### 第二步：初始化并修改配置

先执行：

```bash
bash scripts/install.sh
```

这一步会：
- 复制配置样例为 `config/topic-monitor-config.json`
- 准备 `output/` 目录

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

## 使用示例

下面是一条最小可跑示例：

```bash
git clone https://gitee.com/woipanda/topic-monitor.git
cd topic-monitor
bash scripts/install.sh
export TAVILY_API_KEY='你的 Tavily API Key'
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
```

执行完成后，可直接查看：

```bash
cat ./output/$(TZ=Asia/Shanghai date +%Y-%m-%d)-主题监控日报.md
```

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

## 验收方式

跑完后，至少检查这 4 件事：

```bash
ls -la ./output
TODAY=$(TZ=Asia/Shanghai date +%Y-%m-%d)
[ -s "./output/${TODAY}-主题监控日报.md" ] && echo "输出有内容 ✅" || echo "输出为空 ❌"
grep -n "今日精选\|观察池\|今日判断" "./output/${TODAY}-主题监控日报.md"
```

如果这几项都成立，就说明：
- 主入口可跑
- 配置链打通
- 日报成功生成
- 输出结构符合预期

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
- `topic-monitor 独立工具包`

不建议再把它写成系统内部目录方案。
