#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from dataclasses import asdict
from typing import Any, Dict, List, Sequence

import requests

from search import WebSearchChina

DEFAULT_TIMEOUT = 15
MAX_RESULTS = 20
TAVILY_ENDPOINT = "https://api.tavily.com/search"
CHINA_HINT_KEYWORDS = (
    "国内",
    "中国",
    "大陆",
    "知乎",
    "飞书",
    "微信",
    "微信公众号",
    "公众号",
    "小红书",
    "百度",
    "360",
    "B站",
    "哔哩哔哩",
    "政策",
    "备案",
    "中文社区",
    "方案",
    "教程",
    "部署",
    "自动化",
)
LOW_QUALITY_HOST_KEYWORDS = (
    "mydown.com",
    "gamesteamplay.cn",
    "download",
    "soft",
)
HIGH_QUALITY_HOST_KEYWORDS = (
    ".gov.cn",
    ".org.cn",
    ".edu.cn",
    "github.com",
)


def has_chinese(text: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", text or ""))


def looks_china_oriented(query: str) -> bool:
    q = (query or "").strip()
    if not q:
        return False
    if any(k.lower() in q.lower() for k in CHINA_HINT_KEYWORDS):
        return True
    if has_chinese(q):
        return True
    return False


class TavilySearch:
    def __init__(self) -> None:
        self.api_key = (os.getenv("TAVILY_API_KEY") or "").strip()

    def available(self) -> bool:
        return bool(self.api_key)

    def search(self, query: str, count: int = 5) -> List[dict]:
        if not self.api_key:
            raise RuntimeError("missing TAVILY_API_KEY")

        payload = {
            "api_key": self.api_key,
            "query": query,
            "search_depth": "advanced",
            "topic": "general",
            "max_results": max(1, min(count, 20)),
            "include_answer": False,
            "include_raw_content": False,
        }
        resp = requests.post(
            TAVILY_ENDPOINT,
            headers={"Content-Type": "application/json"},
            json=payload,
            timeout=DEFAULT_TIMEOUT,
        )
        resp.raise_for_status()
        data = resp.json()
        results = []
        for idx, item in enumerate((data.get("results") or [])[:count], start=1):
            title = str(item.get("title") or "").strip()
            url = str(item.get("url") or "").strip()
            snippet = str(item.get("content") or "").strip()
            if not title or not url:
                continue
            results.append(
                {
                    "rank": idx,
                    "title": title,
                    "url": url,
                    "content": snippet,
                    "snippet": snippet,
                    "engine": "tavily",
                    "score": self._score_result(query, title, url, snippet),
                }
            )
        return results

    def _score_result(self, query: str, title: str, url: str, snippet: str) -> float:
        q = (query or "").lower()
        title_l = title.lower()
        snippet_l = snippet.lower()
        score = 0.0
        if q and q in title_l:
            score += 8.0
        if q and q in snippet_l:
            score += 4.0
        for token in re.split(r"\s+", query):
            tok = token.lower().strip()
            if len(tok) <= 1:
                continue
            if tok in title_l:
                score += 2.0
            if tok in snippet_l:
                score += 1.0
        if any(k in url.lower() for k in HIGH_QUALITY_HOST_KEYWORDS):
            score += 2.0
        if any(k in url.lower() for k in LOW_QUALITY_HOST_KEYWORDS):
            score -= 4.0
        return score + 2.0


class SearchRouter:
    def __init__(self) -> None:
        self.china = WebSearchChina()
        self.tavily = TavilySearch()

    def resolve_route(self, query: str, route: str) -> Sequence[str]:
        if route == "china-first":
            return ["china", "tavily"]
        if route == "global-first":
            return ["tavily", "china"]
        if looks_china_oriented(query):
            return ["china", "tavily"]
        return ["tavily", "china"]

    def normalize_provider(self, provider: str, query: str, route_override: str | None = None, mode_override: str | None = None) -> Dict[str, Any]:
        provider = (provider or "auto").strip().lower()
        route = "auto"
        mode = "hybrid"
        force_single = False

        if provider == "auto":
            if self.tavily.available():
                provider = "hybrid"
                mode = mode_override or "hybrid"
                route = route_override or "auto"
            else:
                provider = "china"
                mode = "parallel"
                route = "china-only"
                force_single = True
        elif provider == "hybrid":
            route = route_override or "auto"
            mode = mode_override or "hybrid"
        elif provider == "china":
            route = "china-only"
            mode = "parallel"
            force_single = True
        elif provider == "tavily":
            route = "global-first"
            mode = "fallback"
        else:
            raise ValueError(f"unsupported provider: {provider}")

        if force_single:
            resolved = ["china"]
        else:
            resolved = list(self.resolve_route(query, route if route != "china-only" else "china-first"))
            if provider == "tavily":
                resolved = ["tavily"]
            elif provider == "hybrid" and not self.tavily.available():
                resolved = ["china"]

        return {
            "provider": provider,
            "route": route,
            "mode": mode,
            "resolved_route": resolved,
            "force_single": force_single,
        }

    def search(self, query: str, count: int = 5, provider: str = "auto", route: str | None = None, mode: str | None = None) -> Dict[str, Any]:
        query = (query or "").strip()
        if not query:
            raise ValueError("query is required")

        count = max(1, min(int(count), MAX_RESULTS))
        plan = self.normalize_provider(provider, query, route_override=route, mode_override=mode)
        attempts: List[Dict[str, Any]] = []

        if plan["force_single"]:
            results = [asdict(r) for r in self.china.search(query, engine="auto", count=count, mode="parallel")]
            attempts.append({"provider": "china", "ok": True, "result_count": len(results)})
            return {
                "query": query,
                "provider": plan["provider"],
                "route": plan["route"],
                "mode": plan["mode"],
                "resolved_route": plan["resolved_route"],
                "used_provider": "china" if results else None,
                "attempts": attempts,
                "results": results,
            }

        if plan["provider"] == "tavily":
            results = self.tavily.search(query, count=count)
            attempts.append({"provider": "tavily", "ok": True, "result_count": len(results)})
            return {
                "query": query,
                "provider": plan["provider"],
                "route": plan["route"],
                "mode": plan["mode"],
                "resolved_route": plan["resolved_route"],
                "used_provider": "tavily" if results else None,
                "attempts": attempts,
                "results": results,
            }

        collected: List[dict] = []
        for current in plan["resolved_route"]:
            try:
                if current == "tavily":
                    if not self.tavily.available():
                        raise RuntimeError("missing TAVILY_API_KEY")
                    results = self.tavily.search(query, count=max(3, count))
                else:
                    results = [asdict(r) for r in self.china.search(query, engine="auto", count=max(5, count), mode="parallel")]
                attempts.append({"provider": current, "ok": True, "result_count": len(results)})
                collected.extend(results)
            except Exception as exc:
                attempts.append({"provider": current, "ok": False, "reason": str(exc)})

        merged = self._merge_results(collected, count=count)
        used = self._infer_used_provider(attempts, merged)
        return {
            "query": query,
            "provider": plan["provider"],
            "route": plan["route"],
            "mode": plan["mode"],
            "resolved_route": plan["resolved_route"],
            "used_provider": used,
            "attempts": attempts,
            "results": merged,
        }

    def _infer_used_provider(self, attempts: List[Dict[str, Any]], merged: List[dict]) -> str | None:
        if not merged:
            return None
        ok = [a["provider"] for a in attempts if a.get("ok")]
        if ok == ["china"]:
            return "china"
        if ok == ["tavily"]:
            return "tavily"
        if "china" in ok and "tavily" in ok:
            return "hybrid"
        return ok[0] if ok else None

    def _merge_results(self, items: List[dict], count: int) -> List[dict]:
        best: Dict[str, dict] = {}
        for item in items:
            url = str(item.get("url") or "").strip()
            if not url:
                continue
            key = self._canonicalize_url(url)
            prev = best.get(key)
            if prev is None or float(item.get("score") or 0.0) > float(prev.get("score") or 0.0):
                best[key] = item

        ranked = sorted(best.values(), key=lambda x: float(x.get("score") or 0.0), reverse=True)
        out = []
        for idx, item in enumerate(ranked[:count], start=1):
            item["rank"] = idx
            out.append(item)
        return out

    def _canonicalize_url(self, url: str) -> str:
        from urllib.parse import urlparse
        parsed = urlparse(url)
        return f"{parsed.scheme}://{parsed.netloc}{parsed.path}".rstrip("/").lower()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Topic monitor search router")
    parser.add_argument("query", help="search query")
    parser.add_argument("--count", type=int, default=5)
    parser.add_argument(
        "--provider",
        choices=["auto", "hybrid", "china", "tavily"],
        default="auto",
        help="auto=有 Tavily 就融合，没有就走国内搜索",
    )
    parser.add_argument("--route", choices=["auto", "china-first", "global-first"], default=None)
    parser.add_argument("--mode", choices=["hybrid", "fallback", "parallel"], default=None)
    parser.add_argument("--pretty", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        router = SearchRouter()
        payload = router.search(args.query, count=args.count, provider=args.provider, route=args.route, mode=args.mode)
        if args.pretty:
            print(json.dumps(payload, ensure_ascii=False, indent=2))
        else:
            print(json.dumps(payload, ensure_ascii=False))
        return 0
    except Exception as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
