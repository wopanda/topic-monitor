#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List

import requests

DEFAULT_TIMEOUT = 20
DEFAULT_ENDPOINT = "https://api.bochaai.com/v1/web-search"
MAX_RESULTS = 20


def _bool_from_text(value: str) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def _score_result(query: str, title: str, snippet: str) -> float:
    q = (query or "").lower().strip()
    title_l = (title or "").lower()
    snippet_l = (snippet or "").lower()
    score = 0.0
    if q and q in title_l:
        score += 8.0
    if q and q in snippet_l:
        score += 4.0
    for token in re.split(r"\s+", query or ""):
        tok = token.strip().lower()
        if len(tok) <= 1:
            continue
        if tok in title_l:
            score += 2.0
        if tok in snippet_l:
            score += 1.0
    return score


def bocha_search(query: str, count: int, freshness: str, summary: bool, endpoint: str) -> Dict[str, Any]:
    api_key = (os.getenv("BOCHA_API_KEY") or "").strip()
    if not api_key:
        raise RuntimeError("missing BOCHA_API_KEY")

    payload = {
        "query": query,
        "freshness": freshness,
        "summary": summary,
        "count": max(1, min(int(count), MAX_RESULTS)),
    }

    resp = requests.post(
        endpoint,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=DEFAULT_TIMEOUT,
    )
    resp.raise_for_status()
    data = resp.json()

    values: List[Dict[str, Any]] = []
    payload_root = data.get("data") if isinstance(data, dict) and isinstance(data.get("data"), dict) else data
    web_pages = payload_root.get("webPages") if isinstance(payload_root, dict) else None
    if isinstance(web_pages, dict):
        vals = web_pages.get("value")
        if isinstance(vals, list):
            values = vals

    results: List[Dict[str, Any]] = []
    for idx, item in enumerate(values, start=1):
        title = str(item.get("name") or "").strip()
        url = str(item.get("url") or "").strip()
        snippet = str(item.get("summary") or item.get("snippet") or "").strip()
        if not title or not url:
            continue
        results.append(
            {
                "rank": idx,
                "title": title,
                "url": url,
                "content": snippet,
                "snippet": snippet,
                "engine": "bocha",
                "score": _score_result(query, title, snippet),
            }
        )

    results = sorted(results, key=lambda x: float(x.get("score") or 0.0), reverse=True)
    results = results[: max(1, min(int(count), MAX_RESULTS))]
    for i, item in enumerate(results, start=1):
        item["rank"] = i

    return {
        "query": query,
        "provider": "bocha",
        "route": "bocha-only",
        "mode": "single",
        "resolved_route": ["bocha"],
        "used_provider": "bocha" if results else None,
        "attempts": [{"provider": "bocha", "ok": True, "result_count": len(results)}],
        "results": results,
    }


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Bocha search adapter for topic-monitor")
    p.add_argument("query", help="search query")
    p.add_argument("--count", type=int, default=8)
    p.add_argument("--freshness", default="oneYear")
    p.add_argument("--summary", default="true", help="true/false")
    p.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    p.add_argument("--pretty", action="store_true")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    query = (args.query or "").strip()
    if not query:
        print(json.dumps({"error": "query is required"}, ensure_ascii=False), file=sys.stderr)
        return 1
    try:
        payload = bocha_search(
            query=query,
            count=args.count,
            freshness=args.freshness,
            summary=_bool_from_text(args.summary),
            endpoint=args.endpoint,
        )
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
