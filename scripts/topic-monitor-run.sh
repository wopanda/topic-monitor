#!/bin/bash

# 主题监控日报生成 MVP：少而精、跨天去重、价值说明、建议动作
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${TOPIC_MONITOR_CONFIG:-$REPO_DIR/config/topic-monitor-config.json}"
OUTPUT_DIR="${TOPIC_MONITOR_OUTPUT_DIR:-$REPO_DIR/output}"
TZ_NAME="${TOPIC_MONITOR_TZ:-Asia/Shanghai}"
TODAY=$(TZ="$TZ_NAME" date '+%Y-%m-%d')
OUT_FILE="$OUTPUT_DIR/${TODAY}-主题监控日报.md"
TMP_JSON="/tmp/topic-monitor-search-${TODAY}.json"
TMP_PAYLOAD="/tmp/topic-monitor-payload-${TODAY}.json"
trap 'rm -f "$TMP_JSON" "$TMP_PAYLOAD"' EXIT

mkdir -p "$OUTPUT_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "配置文件不存在: $CONFIG_FILE"
  exit 1
fi

ENABLED=$(jq -r '.enabled' "$CONFIG_FILE")
if [ "$ENABLED" != "true" ]; then
  echo "主题监控已禁用"
  exit 0
fi

TOPIC_NAME=$(jq -r '.topics[0].name // "未命名主题"' "$CONFIG_FILE")
KEYWORDS=$(jq -r '.topics[0].keywords[]?' "$CONFIG_FILE" | paste -sd ' ' -)
KEYWORD_COUNT=$(jq -r '.topics[0].keywords | length' "$CONFIG_FILE")
RAW_PER_KEYWORD=$(jq -r '.output.rawPerKeyword // 4' "$CONFIG_FILE")
MAX_ITEMS=$(jq -r '.output.maxItems // 12' "$CONFIG_FILE")
FINAL_ITEMS=$(jq -r '.output.finalItems // 5' "$CONFIG_FILE")
WATCH_ITEMS=$(jq -r '.output.watchItems // 3' "$CONFIG_FILE")
MIN_SELECTED_SCORE=$(jq -r '.output.minSelectedScore // 5' "$CONFIG_FILE")
MIN_SELECTED_ITEMS=$(jq -r '.output.minSelectedItems // 3' "$CONFIG_FILE")
LOOKBACK_DAYS=$(jq -r '.filters.lookbackDays // 3' "$CONFIG_FILE")
EXCLUDE_JSON=$(jq -c '.filters.excludeKeywords // []' "$CONFIG_FILE")
PREFERRED_DOMAINS_JSON=$(jq -c '.topics[0].preferredDomains // []' "$CONFIG_FILE")
BLOCKED_DOMAINS_JSON=$(jq -c '.topics[0].blockedDomains // []' "$CONFIG_FILE")
TOPIC_PROFILE_JSON=$(jq -c '.topics[0].profile // {}' "$CONFIG_FILE")
TOTAL_RESULTS=$(( KEYWORD_COUNT * RAW_PER_KEYWORD ))
if [ "$TOTAL_RESULTS" -lt "$MAX_ITEMS" ]; then
  MAX_RESULTS="$TOTAL_RESULTS"
else
  MAX_RESULTS="$MAX_ITEMS"
fi

if [ -z "${KEYWORDS:-}" ]; then
  echo "未配置关键词"
  exit 1
fi

echo "关键词: $KEYWORDS"
echo "执行 Tavily 搜索..."

if [ -z "${TAVILY_API_KEY:-}" ]; then
  echo "缺少 TAVILY_API_KEY"
  exit 1
fi

KEYWORDS="$KEYWORDS" MAX_RESULTS="$MAX_RESULTS" python3 - <<'PY' > "$TMP_PAYLOAD"
import json, os
payload = {
    "api_key": os.environ["TAVILY_API_KEY"],
    "query": os.environ["KEYWORDS"],
    "search_depth": "advanced",
    "max_results": int(os.environ["MAX_RESULTS"]),
    "time_range": "day",
}
print(json.dumps(payload, ensure_ascii=False))
PY

curl -sS -X POST "https://api.tavily.com/search" \
  -H "Content-Type: application/json" \
  --data @"$TMP_PAYLOAD" \
  > "$TMP_JSON"

if ! jq -e '.results' "$TMP_JSON" >/dev/null 2>&1; then
  echo "Tavily 返回异常，已生成无新发现报告"
  cat > "$OUT_FILE" <<EOF2
# 📊 主题监控日报 - ${TODAY}

## ⚠️ 今日无新发现

在过去 24 小时内，未获取到可用搜索结果。

### 建议
- 检查 TAVILY_API_KEY 是否有效
- 放宽关键词范围
- 扩大时间窗口到 48h

---
*📅 生成时间: $(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S') (Asia/Shanghai)*
*⚙️ 配置文件: $(basename "$CONFIG_FILE")*
EOF2
  echo "报告已生成: $OUT_FILE"
  exit 0
fi

RAW_COUNT=$(jq -r '.results | length' "$TMP_JSON")

echo "抓取链接详情并生成 MVP 模板报告..."

node - "$TMP_JSON" "$OUT_FILE" "$TODAY" "$TOPIC_NAME" "$KEYWORD_COUNT" "$RAW_COUNT" "$FINAL_ITEMS" "$WATCH_ITEMS" "$LOOKBACK_DAYS" "$EXCLUDE_JSON" "$OUTPUT_DIR" "$MIN_SELECTED_SCORE" "$MIN_SELECTED_ITEMS" "$PREFERRED_DOMAINS_JSON" "$BLOCKED_DOMAINS_JSON" "$TOPIC_PROFILE_JSON" <<'NODE'
const fs = require('fs');
const path = require('path');

const [, , jsonPath, outFile, today, topicName, keywordCount, rawCount, finalItemsArg, watchItemsArg, lookbackDaysArg, excludeJson, reportDir, minSelectedScoreArg, minSelectedItemsArg, preferredDomainsJson, blockedDomainsJson, topicProfileJson] = process.argv;
const finalItemsLimit = Number(finalItemsArg || 5);
const watchItemsLimit = Number(watchItemsArg || 3);
const lookbackDays = Number(lookbackDaysArg || 3);
const minSelectedScore = Number(minSelectedScoreArg || 5);
const minSelectedItems = Number(minSelectedItemsArg || 3);
const excludeKeywords = JSON.parse(excludeJson || '[]');
const preferredDomains = JSON.parse(preferredDomainsJson || '[]');
const blockedDomains = JSON.parse(blockedDomainsJson || '[]');
const topicProfile = JSON.parse(topicProfileJson || '{}');
const entityTerms = Array.isArray(topicProfile.entities) ? topicProfile.entities.map(x => String(x).toLowerCase()) : [];
const preferredContentTypes = Array.isArray(topicProfile.preferredContentTypes) ? topicProfile.preferredContentTypes : [];
const preferredBusinessValues = Array.isArray(topicProfile.preferredBusinessValues) ? topicProfile.preferredBusinessValues : [];
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const results = Array.isArray(data.results) ? data.results : [];

function host(u='') {
  try { return new URL(u).hostname.replace(/^www\./, ''); } catch { return ''; }
}

function urlPath(u='') {
  try { return new URL(u).pathname.toLowerCase(); } catch { return ''; }
}

function looksLikeLowValueByTitleOrUrl(title='', url='') {
  const t = String(title).toLowerCase().trim();
  const h = host(url);
  const p = urlPath(url);
  const lowerUrl = String(url).toLowerCase();

  if (/[?&](page|p)=\d+\b/.test(lowerUrl)) return true;
  if (/\/page\/\d+\b/.test(p)) return true;
  if (/\/(keyword|keywords|tag|tags|category|categories|search)(\/|$)/.test(p)) return true;
  if (h.includes('docs.openclaw.ai') && /\/(start\/showcase|showcase)(\/|$)/.test(p)) return true;
  if (!h.includes('github.com') && /^(openclaw|案例展示(\s*-\s*openclaw)?|showcase(\s*-\s*openclaw)?)$/.test(t)) return true;
  return false;
}

function cleanHtml(html='') {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;|&#160;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

async function fetchDetailText(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 7000);
  try {
    const res = await fetch(url, {
      method: 'GET',
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (OpenClaw Topic Monitor MVP)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    });
    const ct = (res.headers.get('content-type') || '').toLowerCase();
    if (!ct.includes('text/html') && !ct.includes('application/xhtml')) return '';
    const html = await res.text();
    return cleanHtml(html).slice(0, 5000);
  } catch {
    return '';
  } finally {
    clearTimeout(timer);
  }
}

function normalizeTitle(t='') {
  return t.toLowerCase()
    .replace(/【[^】]*】/g, ' ')
    .replace(/[“”"'《》<>「」\[\]()【】|｜:：·,.，。!?？!]/g, ' ')
    .replace(/\b(openclaw|小龙虾|ai|agent|教程|完整|最新|实战|案例|安装|指南|workflow|automation)\b/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function summarize(txt='', n=110) {
  const t = txt.replace(/\s+/g, ' ').trim();
  if (!t) return '暂无摘要';
  return t.length > n ? t.slice(0, n) + '…' : t;
}

function getTags(title='', content='', url='') {
  const txt = `${title} ${content} ${url}`.toLowerCase();
  const tags = [];
  if (txt.includes('github')) tags.push('#github');
  if (txt.includes('workflow')) tags.push('#workflow');
  if (txt.includes('automation') || txt.includes('自动化')) tags.push('#自动化');
  if (txt.includes('best practice') || txt.includes('最佳实践')) tags.push('#最佳实践');
  if (txt.includes('deploy') || txt.includes('部署') || txt.includes('安装')) tags.push('#部署');
  if (txt.includes('risk') || txt.includes('风险') || txt.includes('安全')) tags.push('#风险');
  if (txt.includes('case') || txt.includes('案例') || txt.includes('场景')) tags.push('#案例');
  if (txt.includes('openclaw') || txt.includes('小龙虾')) tags.push('#openclaw');
  return [...new Set(tags)].slice(0, 4);
}

function containsExcluded(text='') {
  const t = text.toLowerCase();
  return excludeKeywords.some(k => t.includes(String(k).toLowerCase()));
}

function looksLikeLowValuePage(item) {
  const h = host(item.url);
  const p = urlPath(item.url);
  const txt = `${item.title} ${item.detailText || item.content || ''}`.toLowerCase();

  if (looksLikeLowValueByTitleOrUrl(item.title, item.url)) return true;
  if (h.endsWith('53ai.com') && p.includes('/keyword/')) return true;
  if (txt.includes('首页 产品服务 热门场景')) return true;
  if (txt.includes('跳转到主要内容') && (txt.includes('navigation') || txt.includes('搜索'))) return true;
  if (txt.includes('openclaw home page') && txt.includes('navigation') && txt.includes('releases')) return true;
  if (txt.includes('免费poc') && txt.includes('首页 产品服务')) return true;
  if (txt.includes('navigation 概览') && txt.includes('搜索')) return true;
  return false;
}

function classifyContentType(item) {
  const h = host(item.url);
  const txt = `${item.title} ${item.detailText || item.content || ''}`.toLowerCase();
  const title = (item.title || '').toLowerCase();

  const isCloudHost = /(aliyun|alibabacloud|tencentcloud|huaweicloud|ctyun|developer\.aliyun|support\.huaweicloud)/.test(h);
  const hasGuideIntent = /(部署|安装|接入|集成|对接|教程|指南|保姆级|快速|faq|quick start|setup|deploy)/.test(txt);
  const hasToolingIntent = /(skill|skills|插件|扩展|tool call|工具调用|agent browser|clawhub install|安装指南|技能)/.test(txt);
  const hasWorkflowIntent = /(workflow|automation|自动化|sop|流程编排|工作流|recipes)/.test(txt);
  const hasUseCaseIntent = /(最佳实践|实践汇总|案例|场景|use case|showcase|客户案例|真实用例)/.test(txt);
  const hasRiskStrong = /(风险|避坑|安全|裸奔|翻车|踩坑|故障|失败复盘|账单暴涨|封号)/.test(title);
  const hasRiskWeak = /(风险|避坑|安全|踩坑|翻车|注意事项|常见问题|faq)/.test(txt);
  const hasReviewIntent = /(测评|评测|对比|横评|盘点|哪个好|review|vs|versus|best)/.test(txt);
  const hasUpdateIntent = /(更新|发布|release|changelog|版本|上线|涨价|降价|pricing|price)/.test(txt);
  const hasNewsIntent = /(新闻|快讯|媒体报道|爆火|融资|发布会|官宣)/.test(txt);

  if (h.includes('github.com')) return 'source';
  if (isCloudHost && /(接入|对接|集成|渠道|钉钉|企业微信|qq|飞书|telegram|slack|discord)/.test(txt)) return 'integration';
  if (hasToolingIntent && !isCloudHost) return 'tooling';
  if (hasReviewIntent) return 'review';
  if (hasUpdateIntent && !hasGuideIntent) return 'product-update';
  if (hasUseCaseIntent && !hasGuideIntent) return 'use-case';
  if (hasWorkflowIntent && !hasToolingIntent) return 'workflow';
  if (hasRiskStrong) return 'risk';
  if (isCloudHost && hasGuideIntent) return 'integration';
  if (/(部署|安装|教程|指南|保姆级|quick start|setup)/.test(txt)) return 'tutorial';
  if (hasRiskWeak && !hasToolingIntent && !isCloudHost) return 'risk';
  if (hasNewsIntent) return 'news';
  return 'general';
}

function contentTypeLabel(type='general') {
  const labels = {
    'source': '源码',
    'integration': '接入/集成',
    'risk': '风险/避坑',
    'tooling': '技能/插件',
    'tutorial': '教程',
    'workflow': '工作流',
    'use-case': '案例/场景',
    'review': '测评/对比',
    'product-update': '产品变更',
    'news': '新闻/动态',
    'general': '通用信息',
  };
  return labels[type] || '通用信息';
}

function classifyBusinessValue(item) {
  const txt = `${item.title} ${item.detailText || item.content || ''}`.toLowerCase();
  const type = item.contentType || classifyContentType(item);

  if (/(生态|市场|趋势|行业|经济学|对比分析|格局|变化|机会)/.test(txt) && !/(教程|安装|部署|接入|指南)/.test(txt)) return 'writing-material';
  if (type === 'risk') return 'risk-alert';
  if (type === 'integration' || type === 'tutorial') return 'deployment-reference';
  if (type === 'product-update' || type === 'review') return 'decision-reference';
  if (type === 'workflow' || type === 'use-case' || type === 'source' || type === 'tooling') return 'case-library';
  return 'observe';
}

function businessValueLabel(value='observe') {
  const labels = {
    'deployment-reference': '部署参考',
    'case-library': '案例沉淀',
    'risk-alert': '风险预警',
    'writing-material': '写书素材',
    'decision-reference': '决策参考',
    'observe': '观察即可',
  };
  return labels[value] || '观察即可';
}

function classifyCluster(item) {
  return classifyContentType(item);
}

function clusterLabel(cluster='general') {
  return contentTypeLabel(cluster);
}

function isPreferredHost(h='') {
  return preferredDomains.some(d => h === d || h.endsWith(`.${d}`));
}

function isBlockedHost(h='') {
  return blockedDomains.some(d => h === d || h.endsWith(`.${d}`));
}

function importanceReason(item) {
  const h = host(item.url);
  const type = item.contentType || classifyContentType(item);
  const value = item.businessValue || classifyBusinessValue(item);

  if (type === 'source') return '这是源码仓库，不是二手转述。真要判断值不值得跟，README、Issue 和最近提交最有信息量。';
  if (type === 'integration') return h.includes('tencentcloud.com') ? '它更像接入说明书，价值不在观点，而在把渠道接起来时有哪些现成步骤可抄。' : '这类内容的价值不在新鲜感，而在步骤和坑位，适合以后真做时拿来对照。';
  if (type === 'risk') return '这条该看的地方，不是它多热，而是它把最容易出事的点提前摊开了。';
  if (type === 'tooling') return '它在回答“哪些工具值得装、怎么接”，比泛泛聊概念更靠近实操。';
  if (type === 'workflow') return '这类内容像流程样板，适合拆成 SOP，不适合只当新闻扫过。';
  if (type === 'use-case') return '它能帮你判断别人到底把这东西用在了什么场景里，适合沉淀成案例。';
  if (type === 'review') return '这类测评的价值，在于帮你缩短试错，而不是替你做决定。';
  if (type === 'product-update') return '这类更新值得看，因为它会直接影响你后面怎么选、怎么用。';
  if (value === 'writing-material') return '它更适合拿来做背景判断或写作素材，不是立刻动手的那类文章。';
  return '信息量还可以，但更像补充材料，不是今天最优先点开的那类。';
}

function nextAction(item) {
  const h = host(item.url);
  const type = item.contentType || classifyContentType(item);
  const value = item.businessValue || classifyBusinessValue(item);

  if (type === 'source') return '先收藏仓库，后面重点看 README、Issue 和最近提交。';
  if (type === 'integration') return h.includes('tencentcloud.com') ? '先留作渠道接入参考，等真要打通时再细看。' : '先放进部署资料夹，等真要复现时再翻。';
  if (type === 'risk') return '别整篇收藏，直接把里面最关键的坑摘成 1 条风险清单。';
  if (type === 'tooling') return '从里面挑 1~2 个最贴近你场景的工具先试，不用一口气全装。';
  if (type === 'workflow') return '把里面能复用的步骤抽成 3 步 SOP，看看能不能塞回你现在的链路。';
  if (type === 'use-case') return '先收进案例库，后面做方案、写书或复盘时再回收利用。';
  if (type === 'review') return '先放观察池，等再出现 1~2 篇对比文时一起判断。';
  if (type === 'product-update') return '先记进产品变化清单，避免后面选型时忘了这个变化。';
  if (value === 'writing-material') return '先丢进写作素材池，后面需要背景判断时再回来看。';
  return '先放观察池，等后面有更多同类信号再决定要不要深看。';
}

function loadHistory(reportDir, today, lookbackDays) {
  const normalizedTitles = new Set();
  const files = [];
  for (let i = 1; i <= lookbackDays; i++) {
    const dt = new Date(`${today}T00:00:00+08:00`);
    dt.setDate(dt.getDate() - i);
    const y = dt.getFullYear();
    const m = String(dt.getMonth() + 1).padStart(2, '0');
    const d = String(dt.getDate()).padStart(2, '0');
    files.push(path.join(reportDir, `${y}-${m}-${d}-主题监控日报.md`));
  }
  for (const file of files) {
    if (!fs.existsSync(file)) continue;
    const text = fs.readFileSync(file, 'utf8');
    for (const m of text.matchAll(/^###\s+\d+\.\s+(.+)$/gm)) {
      normalizedTitles.add(normalizeTitle(m[1].trim()));
    }
  }
  return { normalizedTitles };
}

function scoreItem(item, historyMap) {
  let score = 0;
  const txt = `${item.title} ${item.detailText || item.content || ''}`.toLowerCase();
  const h = host(item.url);

  item.lowValuePage = looksLikeLowValuePage(item);
  item.contentType = classifyContentType(item);
  item.businessValue = classifyBusinessValue(item);

  if (isBlockedHost(h)) score -= 8;
  if (item.lowValuePage) score -= 6;
  if (isPreferredHost(h)) score += 3;

  if (entityTerms.some(t => txt.includes(t))) score += 2;
  if (item.contentType === 'use-case' || item.contentType === 'workflow') score += 2;
  if (item.contentType === 'source') score += 2;
  if (item.businessValue === 'risk-alert') score += 3;
  if (item.businessValue === 'deployment-reference') score += 1;
  if (item.businessValue === 'writing-material') score += 1;
  if (preferredContentTypes.includes(item.contentType)) score += 1;
  if (preferredBusinessValues.includes(item.businessValue)) score += 1;

  if (h.includes('github.com')) score += 3;
  else if (/(aliyun|alibabacloud|huaweicloud|larksuite)/.test(h)) score += 2;
  else if (/(blog|csdn|53ai|zhidx|36kr|8world|cnblogs)/.test(h)) score += 1;

  if (txt.includes('最佳实践') || txt.includes('best practice')) score += 2;
  if (txt.includes('部署') || txt.includes('安装')) score += 1;
  if (txt.includes('教程')) score -= 1;
  if (txt.includes('转载')) score -= 1;
  if (txt.includes('service') || txt.includes('services')) score -= 2;
  if (txt.includes('for smb') || txt.includes('enterprise')) score -= 1;

  if (historyMap.normalizedTitles.has(item.normalizedTitle)) score -= 4;
  if (item.detailText) score += 1;
  if (!item.detailText && !item.content) score -= 2;

  item.score = score;
  item.cluster = item.contentType;
  item.isRepeated = historyMap.normalizedTitles.has(item.normalizedTitle);
  item.blockedHost = isBlockedHost(h);
  return item;
}

function pickDiverseSelected(items, limit) {
  const selected = [];
  const folded = [];
  const domainSeen = new Set();
  const clusterSeen = new Set();

  for (const item of items) {
    const h = host(item.url);
    if (domainSeen.has(h)) {
      item.foldReason = '同域内容已折叠';
      folded.push(item);
      continue;
    }
    if (clusterSeen.has(item.cluster)) {
      item.foldReason = `同类内容已折叠（${clusterLabel(item.cluster)}）`;
      folded.push(item);
      continue;
    }
    selected.push(item);
    domainSeen.add(h);
    clusterSeen.add(item.cluster);
    if (selected.length >= limit) break;
  }

  return { selected, folded };
}

(async () => {
  const historyMap = loadHistory(reportDir, today, lookbackDays);
  const seen = new Set();
  const deduped = [];
  let lowValuePrefiltered = 0;
  for (const r of results) {
    const title = (r.title || '').trim();
    const url = (r.url || '').trim();
    const content = (r.content || '').trim();
    if (!title || !url) continue;
    if (containsExcluded(`${title} ${content}`)) continue;
    if (looksLikeLowValueByTitleOrUrl(title, url)) { lowValuePrefiltered += 1; continue; }
    const normalizedTitle = normalizeTitle(title);
    const key = `${host(url)}|${normalizedTitle.slice(0, 40)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push({ title, url, content, normalizedTitle });
  }

  let detailSuccess = 0;
  const enriched = [];
  for (const item of deduped) {
    const detailText = await fetchDetailText(item.url);
    if (detailText) detailSuccess += 1;
    enriched.push({ ...item, detailText });
  }

  const scored = enriched.map(it => scoreItem(it, historyMap)).sort((a, b) => b.score - a.score);
  const selectedPool = scored.filter(it => !it.blockedHost && !it.lowValuePage && it.score >= minSelectedScore);
  const diversePick = pickDiverseSelected(selectedPool, finalItemsLimit);
  const selected = [...diversePick.selected];
  const folded = diversePick.folded;
  let refillCount = 0;
  const minNeed = Math.min(minSelectedItems, finalItemsLimit);
  if (selected.length < minNeed) {
    const refillPool = selectedPool.filter(it => !selected.includes(it));
    for (const item of refillPool) {
      selected.push(item);
      refillCount += 1;
      if (selected.length >= minNeed) break;
    }
  }
  const watchlistCandidates = [...folded.filter(it => !selected.includes(it)), ...scored.filter(it => !selected.includes(it) && !it.blockedHost && !it.lowValuePage && !folded.includes(it))];
  const watchlist = watchlistCandidates.slice(0, watchItemsLimit);

  const trendBullets = [];
  if (selected.some(x => /风险|安全/.test(`${x.title} ${x.detailText || x.content || ''}`))) trendBullets.push('新增内容里出现了风险/避坑信号，说明市场开始从“尝鲜”转向“稳定使用”。');
  if (selected.some(x => /部署|安装|workflow|automation|自动化/.test(`${x.title} ${x.detailText || x.content || ''}`.toLowerCase()))) trendBullets.push('高分内容仍集中在部署、自动化和 workflow，说明大家最关心的还是如何真正跑起来。');
  if (selected.some(x => host(x.url).includes('github.com'))) trendBullets.push('GitHub 源进入精选，说明这次不只是媒体二次传播，已经有一线实践信号。');
  if (trendBullets.length === 0) trendBullets.push('今天新增内容以教程/案例为主，说明热度仍在，但真正新增洞察有限。');

  const nowCn = new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Shanghai', hour12: false }).replace('T', ' ');
  let md = `# 📊 主题监控日报 - ${today}\n\n`;
  md += `> 🤖 由 OpenClaw AI 自动生成（MVP：少而精版）\n\n`;
  md += `## 🎯 监控主题\n- ${topicName}\n\n---\n\n`;
  md += `## ✅ 今日精选 (${selected.length} 条)\n\n`;
  if (selected.length === 0) {
    md += `今天没有筛出真正值得看的新增内容。\n\n`;
  } else {
    selected.forEach((it, i) => {
      const baseText = it.detailText || it.content || '';
      md += `### ${i + 1}. ${it.title}\n\n`;
      md += `**📝 摘要**: ${summarize(baseText)}\n\n`;
      md += `**🧩 内容类型**: ${contentTypeLabel(it.contentType)}\n\n`;
      md += `**🎯 业务价值**: ${businessValueLabel(it.businessValue)}\n\n`;
      md += `**🔗 来源**: [${host(it.url) || '原文'}](${it.url})\n\n`;
      md += `**⭐ 入选原因**: ${importanceReason(it)}\n\n`;
      md += `**➡️ 建议动作**: ${nextAction(it)}\n\n`;
      md += `**🏷️ 标签**: ${(getTags(it.title, baseText, it.url).join(' ') || '#资讯')}\n\n`;
      md += `---\n\n`;
    });
  }
  md += `## 👀 观察池 (${watchlist.length} 条)\n\n`;
  if (watchlist.length === 0) {
    md += `暂无额外观察项。\n\n`;
  } else {
    watchlist.forEach((it, i) => {
      const reason = it.foldReason || (it.isRepeated ? '疑似跨天重复，暂不进入精选。' : '信息增量一般，先放观察池。');
      md += `${i + 1}. ${it.title} —— 分数 ${it.score}，${reason}\n`;
    });
    md += `\n`;
  }
  md += `## 💡 今日判断\n`;
  trendBullets.slice(0, 3).forEach(t => { md += `- ${t}\n`; });
  md += `\n`;
  md += `## 📈 统计\n`;
  md += `- 🔍 搜索关键词: ${keywordCount} 个\n`;
  md += `- 📥 原始结果: ${rawCount} 条\n`;
  md += `- 🔄 当日去重后: ${deduped.length} 条\n`;
  md += `- 🧹 低价值页压制: ${lowValuePrefiltered + scored.filter(x => x.lowValuePage).length} 条\n`;
  md += `- 🪞 同质内容折叠: ${folded.length} 条\n`;
  md += `- 🩹 保底补位: ${refillCount} 条\n`;
  md += `- 🚫 跨天重复压制: ${scored.filter(x => x.isRepeated).length} 条\n`;
  md += `- ✅ 今日精选: ${selected.length} 条\n`;
  md += `- 👀 观察池: ${watchlist.length} 条\n`;
  md += `- 📄 详情抓取成功: ${detailSuccess}/${deduped.length} 条\n\n`;
  md += `---\n`;
  md += `*📅 生成时间: ${nowCn} (Asia/Shanghai)*\n`;
  md += `*⚙️ 配置文件: topic-monitor-config.json*\n`;
  md += `*🧩 模板版本: MVP v10（主题卡 / 双轴分类 / 同质折叠 / 人话原因）*\n`;
  fs.writeFileSync(outFile, md, 'utf8');
})().catch((err) => { console.error(err); process.exit(1); });
NODE

echo "报告已生成: $OUT_FILE"
cat "$OUT_FILE"
