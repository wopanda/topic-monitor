---
name: topic-monitor
description: Use when a reusable topic-monitoring capability needs one stable entrypoint, one config entry, and a structured markdown report for repeated external-information scanning.
---

# topic-monitor

## Overview

topic-monitor 是一个可复用的主题监控能力包。
它把围绕固定主题的外部信息扫描，压成一份结构化 markdown 日报。

核心约束只有三条：
- 一个稳定主入口
- 一个稳定配置入口
- 一个稳定输出结果

## When to Use

适合：
- 需要围绕固定主题持续监控外部信息
- 需要按配置文件调整关键词、来源和筛选口径
- 需要把结果稳定写成日报，而不是停留在终端输出
- 需要一个可安装、可验证、可复用的能力包，而不是一次性脚本

不适合：
- 一次性的临时搜索
- 替人直接下最终判断
- 完整知识管理或长期记忆系统

## Quick Reference

- 主入口：`scripts/topic-monitor-run.sh`
- 初始化：`scripts/install.sh`
- 配置样例：`config/topic-monitor-config.example.json`
- 运行配置：`config/topic-monitor-config.json`
- 示例输出：`examples/sample-report.md`

## Verification

最小验收方式：

```bash
bash scripts/install.sh
export TAVILY_API_KEY='你的 Tavily API Key'
TOPIC_MONITOR_OUTPUT_DIR=./output bash scripts/topic-monitor-run.sh
TODAY=$(TZ=Asia/Shanghai date +%Y-%m-%d)
[ -s "./output/${TODAY}-主题监控日报.md" ] && echo "输出有内容 ✅" || echo "输出为空 ❌"
```

如果输出文件存在且非空，就说明：
- 主入口可跑
- 配置链打通
- 日报生成成功
