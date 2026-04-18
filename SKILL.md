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

核心约束仍然是：
- 一个稳定主入口
- 一个稳定配置入口
- 一个稳定输出结果

## When to Use

适合：
- 需要围绕固定主题持续监控外部信息
- 需要按配置文件调整关键词、来源和筛选口径
- 需要把结果稳定写成日报，而不是停留在终端输出
- 需要一个可安装、可验证、可复用的能力包，而不是一次性脚本
- 需要接入 **Bocha Search API** 做稳定检索

不适合：
- 一次性的临时搜索
- 替人直接下最终判断
- 完整知识管理或长期记忆系统

## Quick Reference

- 主入口：`scripts/topic-monitor-run.sh`
- 初始化：`scripts/install.sh`
- Bocha 搜索层：`scripts/search_bocha.py`
- 日报渲染：`scripts/topic-monitor-render.js`
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
