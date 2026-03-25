---
name: topic-monitor
description: Use when a reusable topic-monitoring capability needs one stable entrypoint, optional Tavily support, China-search fallback, and a structured markdown report for repeated external-information scanning.
---

# topic-monitor

## Overview

topic-monitor 是一个可复用的主题监控能力包。
它把围绕固定主题的外部信息扫描，压成一份结构化 markdown 日报。

这版的关键变化是：
- **Tavily 变成可选项，不再是硬依赖**
- 默认支持 **有 key 走融合、没 key 自动退回 China 搜索**

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
- 需要在 **无 Tavily key** 时仍能继续获得可用结果

不适合：
- 一次性的临时搜索
- 替人直接下最终判断
- 完整知识管理或长期记忆系统

## Quick Reference

- 主入口：`scripts/topic-monitor-run.sh`
- 初始化：`scripts/install.sh`
- 国内搜索层：`scripts/search.py`
- 自动路由层：`scripts/search_router.py`
- 日报渲染：`scripts/topic-monitor-render.js`
- 配置样例：`config/topic-monitor-config.example.json`
- 运行配置：`config/topic-monitor-config.json`
- 示例输出：`examples/sample-report.md`

## Search Behavior

读者侧默认只需要使用**自动模式**。

系统会自动处理：
- 有 `TAVILY_API_KEY` → 自动增强
- 没有 `TAVILY_API_KEY` → 自动退回保底搜索

`provider / route / mode` 这些配置保留给开发和调试使用，不建议作为读者主口径。

## Verification

最小验收方式：

```bash
bash scripts/install.sh
pip3 install -r requirements.txt
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
TODAY=$(TZ=Asia/Shanghai date +%Y-%m-%d)
[ -s "./output/${TODAY}-主题监控日报.md" ] && echo "输出有内容 ✅" || echo "输出为空 ❌"
```

如果你额外注入：

```bash
export TAVILY_API_KEY='你的 Tavily API Key'
```

则会自动启用融合搜索。
