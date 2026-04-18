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
const results = Array.isArray(data) ? data : (Array.isArray(data.results) ? data.results : []);
const usedProvider = Array.isArray(data) ? 'china' : (data.used_provider || 'unknown');
const resolvedRoute = Array.isArray(data) ? 'china-only' : ((data.resolved_route || []).join(' -> '));
const attemptsSummary = Array.isArray(data) ? 'china:ok' : ((data.attempts || []).map(x => x.ok ? `${x.provider}:ok:${x.result_count || 0}` : `${x.provider}:fail:${x.reason || 'unknown'}`).join(' | '));
const debugMode = ['1', 'true', 'yes'].includes(String(process.env.TOPIC_MONITOR_DEBUG || '').toLowerCase());

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
  const txt = `${item.title} ${item.detailText || item.content || item.snippet || ''}`.toLowerCase();

  if (looksLikeLowValueByTitleOrUrl(item.title, item.url)) return true;
  if (h.endsWith('53ai.com') && p.includes('/keyword/')) return true;
  if (txt.includes('首页 产品服务 热门场景')) return true;
  if (txt.includes('跳转到主要内容') && (txt.includes('navigation') || txt.includes('搜索'))) return true;
  if (txt.includes('openclaw home page') && txt.includes('navigation') && txt.includes('releases')) return true;
  if (txt.includes('免费poc') && txt.includes('首页 产品服务')) return true;
  if (txt.includes('navigation 概览') && txt.includes('搜索')) return true;
  if (txt.includes('ai 智能聊天') && txt.includes('问答助手') && txt.includes('免费无限量使用')) return true;
  if (txt.includes('☞☞☞') || txt.includes('☜☜☜')) return true;
  return false;
}

function classifyContentType(item) {
  const h = host(item.url);
  const txt = `${item.title} ${item.detailText || item.content || item.snippet || ''}`.toLowerCase();
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
  const txt = `${item.title} ${item.detailText || item.content || item.snippet || ''}`.toLowerCase();
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

function readerReason(item) {
  const h = host(item.url);
  const type = item.contentType || classifyContentType(item);
  if (type === 'source') return '这是一手仓库，后面真要深入时可以先从这里开始。';
  if (type === 'workflow') return '这条更像现成思路，适合直接借鉴做法。';
  if (type === 'use-case') return '这里有真实使用场景，适合快速判断别人怎么在用。';
  if (type === 'integration') return '这条更偏落地接入，后面真要上手时会有参考价值。';
  if (type === 'tutorial') return '这条适合快速上手，能帮你少走一点弯路。';
  if (type === 'risk') return '这条能帮你提前看到坑点，避免后面再补课。';
  if (h.includes('github.com')) return '这是源码入口，通常比二手整理更值得先看。';
  return '这条信息增量还不错，适合先纳入今天的重点观察。';
}

function shortJudgment(selected, trendBullets) {
  if (selected.some(x => x.contentType === 'source') && selected.some(x => x.contentType === 'workflow')) {
    return '今天这批结果里，既有一手仓库，也有可直接借鉴的用例内容。';
  }
  if (selected.some(x => x.contentType === 'tutorial')) {
    return '今天新增内容更偏上手和部署，适合做一轮轻量了解。';
  }
  if (trendBullets.length > 0) return trendBullets[0].replace('新增内容里出现了风险/避坑信号，说明市场开始从“尝鲜”转向“稳定使用”。', '今天能看到一些避坑和落地信号，说明讨论开始变得更务实了。');
  return '今天新增内容整体还算扎实，适合先收下再决定要不要深挖。';
}

function shortWatchReason(item) {
  if (item.foldReason) return item.foldReason;
  if (item.isRepeated) return '疑似与前几天重复';
  return '先留着观察';
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
  const txt = `${item.title} ${item.detailText || item.content || item.snippet || ''}`.toLowerCase();
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

  if (/(github\.com|docs\.openclaw\.ai|openclaw\.ai)/.test(h)) score += 4;
  else if (/(aliyun|alibabacloud|huaweicloud|larksuite|tencentcloud)/.test(h)) score += 2;
  else if (/(zhidx|36kr)/.test(h)) score += 1;

  if (/(csdn|cnblogs|toutiao|baijiahao|sohu\.com|news\.qq\.com|163\.com)/.test(h)) score -= 2;

  if (txt.includes('最佳实践') || txt.includes('best practice')) score += 2;
  if (txt.includes('部署') || txt.includes('安装')) score += 1;
  if (txt.includes('教程')) score -= 1;
  if (txt.includes('转载')) score -= 1;
  if (/你能想到|爆火|最全|保姆级|一文读懂|手把手/.test(item.title || '')) score -= 1;
  if (txt.includes('service') || txt.includes('services')) score -= 2;
  if (txt.includes('for smb') || txt.includes('enterprise')) score -= 1;
  if (/(use case|usecase|案例|场景|workflow|automation)/.test(txt)) score += 1;

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
  if (selected.some(x => /风险|安全/.test(`${x.title} ${x.detailText || x.content || x.snippet || ''}`))) trendBullets.push('新增内容里出现了风险/避坑信号，说明市场开始从“尝鲜”转向“稳定使用”。');
  if (selected.some(x => /部署|安装|workflow|automation|自动化/.test(`${x.title} ${x.detailText || x.content || x.snippet || ''}`.toLowerCase()))) trendBullets.push('高分内容仍集中在部署、自动化和 workflow，说明大家最关心的还是如何真正跑起来。');
  if (selected.some(x => host(x.url).includes('github.com'))) trendBullets.push('GitHub 源进入精选，说明这次不只是媒体二次传播，已经有一线实践信号。');
  if (trendBullets.length === 0) trendBullets.push('今天新增内容以教程/案例为主，说明热度仍在，但真正新增洞察有限。');

  const nowCn = new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Shanghai', hour12: false }).replace('T', ' ');
  let md = `# 主题监控日报 | ${today}

`;
  md += `## 今天关注什么
- ${topicName}

`;
  md += `## 今天最值得看
`;
  if (selected.length === 0) {
    md += `- 今天没有筛出真正值得看的新增内容。

`;
  } else {
    selected.forEach((it, i) => {
      md += `${i + 1}. **${it.title}**
`;
      md += `   - 值得看：${readerReason(it)}
`;
      md += `   - 链接：${it.url}
`;
    });
    md += `
`;
  }
  md += `## 今天看到的变化
`;
  md += `- ${shortJudgment(selected, trendBullets)}

`;
  md += `## 还可以顺手看看
`;
  if (watchlist.length === 0) {
    md += `- 暂无。

`;
  } else {
    watchlist.slice(0, 3).forEach((it) => {
      md += `- ${it.title}（${shortWatchReason(it)}）
`;
    });
    md += `
`;
  }
  if (debugMode) {
    md += `## 调试信息
`;
    md += `- 原始结果: ${rawCount} 条
`;
    md += `- 去重后: ${deduped.length} 条
`;
    md += `- 低价值页压制: ${lowValuePrefiltered + scored.filter(x => x.lowValuePage).length} 条
`;
    md += `- 同质内容折叠: ${folded.length} 条
`;
    md += `- 跨天重复压制: ${scored.filter(x => x.isRepeated).length} 条
`;
    md += `- 详情抓取成功: ${detailSuccess}/${deduped.length} 条
`;
    md += `- 使用搜索源: ${usedProvider}
`;
    md += `- 路由计划: ${resolvedRoute || 'unknown'}
`;
    md += `- 尝试记录: ${attemptsSummary || 'unknown'}

`;
  }
  md += `---
`;
  md += `*生成时间：${nowCn} (Asia/Shanghai)*
`;
  md += `*默认使用 Bocha Search API。*
`;
  fs.writeFileSync(outFile, md, 'utf8');
})().catch((err) => { console.error(err); process.exit(1); });