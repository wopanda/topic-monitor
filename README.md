# topic-monitor

把“每天先刷一轮外部信息”压成一份主题监控日报的轻量工具包。

## 这是什么

这个仓库提供的是 4.1 主案例对应的读者版交付包：
- 主入口脚本：`scripts/topic-monitor-run.sh`
- 配置样例：`config/topic-monitor-config.example.json`
- 示例产物：`examples/2026-03-18-主题监控日报.md`

它解决的不是“替你做最终判断”，而是先把搜、抓、粗筛、整理这一轮重复劳动接走，再把结果写成一份日报。

## 主入口口径

当前唯一主入口是：

`bash scripts/topic-monitor-run.sh`

读者后续只需要围绕这个脚本理解、配置和运行即可。

## 依赖项

运行前请先准备：
- Bash
- `curl`
- `jq`
- Node.js 18+
- Tavily API Key（环境变量：`TAVILY_API_KEY`）

可用下面这条命令快速自检：

```bash
bash --version >/dev/null && curl --version >/dev/null && jq --version >/dev/null && node --version
```

## 3 步安装 / 运行

### 第一步：获取代码

```bash
git clone https://gitee.com/woipanda/topic-monitor.git
cd topic-monitor
```

### 第二步：复制并修改配置

```bash
cp config/topic-monitor-config.example.json config/topic-monitor-config.json
```

然后编辑 `config/topic-monitor-config.json`。

最关键的入口就是这个文件。你至少要改这几项：
- `topics[0].name`：你的监控主题名
- `topics[0].keywords`：你真正想盯的关键词
- `topics[0].preferredDomains` / `blockedDomains`：你偏好的信源和要压掉的域名
- `output.finalItems` / `output.watchItems`：你希望每天看到多少精选、多少观察池

再准备 Tavily Key：

```bash
export TAVILY_API_KEY='你的 Tavily API Key'
```

### 第三步：手动运行并查看日报

```bash
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
ls -lh ./output
cat ./output/$(TZ=Asia/Shanghai date +%Y-%m-%d)-主题监控日报.md
```

这一步会：
- 读取 `config/topic-monitor-config.json`
- 调 Tavily 搜索近 24 小时结果
- 抓详情、压低价值页、做精选 / 观察池分流
- 把日报写到 `./output/`

## 关键路径说明

- 配置文件路径：`config/topic-monitor-config.json`
- 主入口脚本：`scripts/topic-monitor-run.sh`
- 手动运行命令：`TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh`
- 输出文件路径：`./output/YYYY-MM-DD-主题监控日报.md`

## 这个脚本实际会做什么

主动作链可以简单理解成 6 步：
1. 定主题
2. 搜结果
3. 抓详情
4. 压低价值页
5. 做精选 / 观察池分流
6. 写回日报

所以正文最该写的，不是参数表，而是这条动作链怎么把“刷网页”变成“先看日报”。

## 配置字段速读

### schedule
- `time`：计划运行时间
- `timezone`：时区

### topics[0]
- `name`：主题名
- `keywords`：搜索关键词数组
- `preferredDomains`：优先信源
- `blockedDomains`：屏蔽域名
- `profile`：偏好的内容类型和业务价值

### output
- `maxItems`：原始抓回上限
- `finalItems`：精选条数
- `watchItems`：观察池条数
- `minSelectedScore`：进入精选的最低分

### filters
- `excludeKeywords`：排除词
- `lookbackDays`：跨天去重回看窗口

## 示例输出

仓库里附了一份真实样例：

- `examples/2026-03-18-主题监控日报.md`

如果你想判断“这东西写回来的到底像不像日报”，先看这个文件就够了。

## 常见问题

### 1) 报错 `缺少 TAVILY_API_KEY`
说明你还没导出环境变量：

```bash
export TAVILY_API_KEY='你的 Tavily API Key'
```

### 2) 报错 `jq: command not found`
先安装 `jq`。

Ubuntu / Debian：
```bash
sudo apt-get update && sudo apt-get install -y jq
```

macOS（Homebrew）：
```bash
brew install jq
```

### 3) 想改输出目录
直接改运行时环境变量：

```bash
TOPIC_MONITOR_OUTPUT_DIR="$HOME/TopicReports" bash scripts/topic-monitor-run.sh
```

## 一句话理解

这不是一个“万能情报系统”，而是一条已经能跑起来的日报动作链：先帮你看一轮、筛一轮、整理一轮，再把值得你接手的结果送回来。
