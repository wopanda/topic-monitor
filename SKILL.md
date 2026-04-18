---
name: topic-monitor
description: Use when a reusable topic-monitoring capability needs one stable entrypoint, Bocha Search API retrieval, and a structured markdown report for repeated external-information scanning.
---

# topic-monitor

## Overview

topic-monitor 是一个可复用的主题监控能力包。
它把围绕固定主题的外部信息扫描，压成一份结构化 markdown 日报。

这版的关键变化是：
- 搜索层统一切到 **Bocha Search API**
- 不再走 Tavily / China 混合路由
- 产品层默认采用：**先生成日报，再询问是否开启定时发布**

核心约束仍然是：
- 一个稳定主入口
- 一个稳定配置入口
- 一个稳定输出结果
- 定时发布通过 **OpenClaw cron** 完成，而不是在 skill 内部硬编码发送

## When to Use

适合：
- 需要围绕固定主题持续监控外部信息
- 需要按配置文件调整关键词、来源和筛选口径
- 需要把结果稳定写成日报，而不是停留在终端输出
- 需要一个可安装、可验证、可复用的能力包，而不是一次性脚本
- 需要接入 **Bocha Search API** 做稳定检索
- 需要先看样稿，再决定要不要接定时发布

不适合：
- 一次性的临时搜索
- 替人直接下最终判断
- 完整知识管理或长期记忆系统
- 未经确认就默认自动开始每天发送

## Quick Reference

- 主入口：`scripts/topic-monitor-run.sh`
- 初始化：`scripts/install.sh`
- Bocha 搜索层：`scripts/search_bocha.py`
- 日报渲染：`scripts/topic-monitor-render.js`
- 定时创建辅助：`scripts/create-openclaw-cron.sh`
- 配置样例：`config/topic-monitor-config.example.json`
- 运行配置：`config/topic-monitor-config.json`
- 示例输出：`examples/sample-report.md`

## Search Behavior

读者侧默认使用 **Bocha 单引擎模式**。

必须提供：
- `BOCHA_API_KEY`

关键配置项：
- `search.provider`（固定为 `bocha`）
- `search.endpoint`
- `search.freshness`
- `search.summary`

## Delivery Behavior

### 手动运行后的默认动作
当用户先手动看过一次日报、且还没有明确说要不要定时发布时：
- 默认要**补问一句**：是否要设置定时发布
- 不要直接假定用户一定要开定时
- 不要把“生成日报”和“自动发送”强耦合在一个脚本里

推荐追问口径：
- `这版先给你跑出来了。要不要顺手给你设成每天 {HH:MM} 自动发？`

### 定时发布的实现方式
参考现有成功案例，定时发布应采用：
- **OpenClaw cron**
- 默认用配置里的 `schedule.time` + `schedule.timezone`
- 默认投递到当前用户确认的会话目标

不要使用：
- 系统 `crontab`
- skill 内部自己调用发送工具硬发
- 让日报生成脚本同时承担调度器职责

### 只有在用户明确同意后才创建 cron
用户明确说“要”“设置一下”“每天发”后，才创建定时任务。

推荐方式：
- Feishu 场景：优先直接问用户是否开启
- 创建命令：`openclaw cron add ...`
- 当前仓库辅助脚本：`scripts/create-openclaw-cron.sh`

### Cron 任务消息要求
定时任务里的消息应只做一件事：
- 运行 `topic-monitor`
- 生成当天日报
- 输出最终日报用于投递
- **不要在 cron 运行里再次追问用户是否设置定时发布**

## Delivery Strategy

默认分两层：

1. **内容生产层**
   - 负责搜索、筛选、生成日报 markdown
2. **定时发布层**
   - 负责按时间触发，并在用户确认后接入外层发送

默认产品策略：
- 第一次先生成日报样稿
- 样稿确认后，再问用户是否要开启定时发布
- 不默认在 skill 内部直接调用消息发送

参考：`references/scheduled-delivery.md`

## Verification

最小验收方式：

```bash
bash scripts/install.sh
pip3 install -r requirements.txt
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
TODAY=$(TZ=Asia/Shanghai date +%Y-%m-%d)
[ -s "./output/${TODAY}-主题监控日报.md" ] && echo "输出有内容 ✅" || echo "输出为空 ❌"
```

运行前先注入：

```bash
export BOCHA_API_KEY='你的 Bocha API Key'
```

然后执行运行命令即可。

如果要预览定时发布命令：

```bash
bash scripts/create-openclaw-cron.sh --to user:ou_xxx
```

真正创建时再加：

```bash
bash scripts/create-openclaw-cron.sh --to user:ou_xxx --create
```
