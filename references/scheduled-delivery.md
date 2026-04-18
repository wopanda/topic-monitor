# 定时发布推荐方案

## 默认产品策略

`topic-monitor` 默认分两层：

1. **内容生产层**
   - 负责搜索、筛选、生成日报 markdown
   - 主入口：`scripts/topic-monitor-run.sh`

2. **定时发布层**
   - 负责按时间触发、运行日报生成、把最终日报投递到目标会话
   - 推荐使用 **OpenClaw cron** 完成

## 为什么不建议把发送硬编码进 skill 本体

原因：
- 搜索生成和消息投递是两种不同职责
- 换渠道时（Feishu / WeCom / Telegram）不应该重写 skill 核心逻辑
- 出错时更容易区分是“日报生成失败”还是“发送失败”
- 更接近现有成功案例：**OpenClaw cron + 当前会话投递**

## 推荐默认流程

### 第一次使用
1. 用户先跑通一次日报生成
2. 用户先看样稿，确认：
   - 主题对不对
   - 输出风格对不对
   - 来源过滤是否过严 / 过松
3. **第一次跑通后，再问用户是否要开启定时发布**

建议问法：
- 要不要把这个主题监控设成每天自动发？
- 如果要，我就按配置里的时间和时区接上外层调度。

### 用户确认开启定时发布后
1. 用 `openclaw cron add` 创建任务
2. cron 按 `schedule.time` + `schedule.timezone` 每天触发一次
3. cron 运行时执行 topic-monitor，生成当日日报
4. cron 将最终输出投递到用户确认的目标会话

辅助脚本：

```bash
bash scripts/create-openclaw-cron.sh --to user:ou_xxx --create
```

群聊目标示例：

```bash
bash scripts/create-openclaw-cron.sh --to chat:oc_xxx --create
```

## 默认值口径

如果用户未指定具体时间，但明确说“开启定时发布”，推荐默认值：
- 时间：`09:00`
- 时区：`Asia/Shanghai`
- 发送方式：OpenClaw cron

## 不建议的方案

不建议默认采用：
- skill 内部自己等待到点
- skill 内部硬编码调用某一个渠道 SDK
- 系统 `crontab`
- 未经用户确认就自动开始每天发送

## 适合 agent 的执行口径

当用户说：
- “先帮我试跑” → 只生成日报，不自动发
- “先看看样子” → 先出日报样稿，再问是否开启定时
- “可以，帮我每天发” → 用 OpenClaw cron 创建定时任务

推荐追问：

```text
这版先跑出来了。要不要按当前配置给你设成每天 09:00 自动发？
```
