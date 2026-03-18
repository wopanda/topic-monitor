---
name: topic-monitor
summary: 把固定主题的外部信息抓取、粗筛并整理成一份结构化日报的能力包。
version: 1
entry:
  script: scripts/topic-monitor-run.sh
config:
  example: config/topic-monitor-config.example.json
output:
  example: examples/sample-report.md
---

# topic-monitor

这是一个**符合 Skill 规范的能力包**，但书内对外表述统一建议写成：
- `topic-monitor 主题监控工具包`
- `topic-monitor 独立工具包`

## 这份文件的作用
- 给技术交付层一个稳定入口
- 明确主脚本、配置样例、示例输出
- 让这个能力后续可以被安装、复用、验证

## 唯一主入口
- `scripts/topic-monitor-run.sh`

## 配置入口
- `config/topic-monitor-config.example.json`
- 实际使用时复制为：`config/topic-monitor-config.json`

## 示例输出
- `examples/sample-report.md`

## 注意
- 书里不要把它写成“一个 Skill 教程”
- 书里重点仍然是：动作链、日报产物、人机边界
- `SKILL.md` 的存在，是为了让技术交付形态更完整，而不是把正文写回系统内部结构说明
