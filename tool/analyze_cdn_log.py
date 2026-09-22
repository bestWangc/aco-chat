#!/usr/bin/env python3
"""统计 CDN/HTTP 请求日志，定位头像、封面、聊天图片和重复请求。

用法：python3 tool/analyze_cdn_log.py request.log --top 50
支持：Nginx/Apache combined、常见空格分隔 CDN 日志、CSV、JSON Lines。
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import parse_qsl, urlsplit

REQ_RE = re.compile(r'"(?P<method>[A-Z]+) (?P<target>\S+) HTTP/[0-9.]+"\s+(?P<status>\d{3})(?:\s+(?P<size>\d+|-))?')
COMMON_RE = re.compile(r'(?P<ip>\S+)\s+\S+\s+\S+\s+\[[^]]+\]\s+' + REQ_RE.pattern)
CDN_RE = re.compile(r'"(?P<method>[A-Z]+) (?P<target>\S+)"\s+(?P<status>\d{3})\s+\S+\s+(?P<size>\d+)')

def classify(path: str) -> str:
    p = path.lower()
    if any(x in p for x in ("avatar", "head", "face", "portrait")):
        return "头像"
    if any(x in p for x in ("live-cover", "cover", "thumbnail", "thumb")):
        return "封面/缩略图"
    if any(x in p for x in ("chat", "chat-files", "message", "upload", "image", "photo", "picture")):
        return "聊天/图片"
    if re.search(r"\.(jpg|jpeg|png|webp|gif|avif|heic)(?:$|\?)", p):
        return "图片(未识别)"
    return "其他"

def parse_line(line: str):
    line = line.strip()
    if not line:
        return None
    if line.startswith("{"):
        try:
            obj = json.loads(line)
            target = obj.get("request_uri") or obj.get("uri") or obj.get("url") or obj.get("path")
            if not target:
                return None
            return obj.get("method", "GET"), target, int(obj.get("status", obj.get("status_code", 0)) or 0), int(obj.get("body_bytes_sent", obj.get("bytes", obj.get("size", 0))) or 0)
        except (ValueError, TypeError):
            return None
    # CDN export format used by wffw.swgcl.com: "METHOD URL" status
    # response_time response_bytes cache_status ...
    m = CDN_RE.search(line)
    if m:
        return m.group("method"), m.group("target"), int(m.group("status")), int(m.group("size"))
    m = COMMON_RE.search(line) or REQ_RE.search(line)
    if m:
        size = m.groupdict().get("size") or "0"
        return m.group("method"), m.group("target"), int(m.group("status")), 0 if size == "-" else int(size)
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log", type=Path)
    ap.add_argument("--top", type=int, default=30)
    ap.add_argument("--json", action="store_true", dest="as_json")
    args = ap.parse_args()
    counts = Counter(); bytes_by = Counter(); statuses = Counter(); methods = Counter(); query_keys = Counter()
    unique = defaultdict(set); parsed = bad = 0
    with args.log.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            row = parse_line(line)
            if not row:
                bad += 1; continue
            method, target, status, size = row
            u = urlsplit(target)
            key = u.path or "/"
            category = classify(key)
            parsed += 1; counts[(category, key)] += 1; bytes_by[(category, key)] += size
            statuses[status] += 1; methods[method] += 1
            unique[category].add(key)
            query_keys.update(k for k, _ in parse_qsl(u.query, keep_blank_values=True))
    cat_counts = Counter(); cat_bytes = Counter()
    for (cat, _), n in counts.items():
        cat_counts[cat] += n; cat_bytes[cat] += bytes_by[(cat, _)]
    rows = []
    for (cat, path), n in counts.most_common():
        rows.append({"category": cat, "path": path, "requests": n, "bytes": bytes_by[(cat, path)], "unique_paths": len(unique[cat])})
    report = {"parsed": parsed, "unparsed": bad, "categories": {c: {"requests": cat_counts[c], "bytes": cat_bytes[c], "unique_paths": len(unique[c])} for c in cat_counts}, "statuses": dict(statuses), "methods": dict(methods), "query_keys": query_keys.most_common(30), "top_paths": rows[:args.top]}
    if args.as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2)); return
    print(f"解析成功 {parsed:,} 行，无法识别 {bad:,} 行")
    print("\n分类汇总（按响应字节）")
    for cat, v in sorted(report["categories"].items(), key=lambda x: x[1]["bytes"], reverse=True):
        print(f"{cat:12} 请求 {v['requests']:>10,}  流量 {v['bytes']/1024/1024:>10.2f} MiB  不同路径 {v['unique_paths']}")
    print("\nTop 路径（按请求数）")
    for r in rows[:args.top]:
        print(f"{r['requests']:>10,} 次  {r['bytes']/1024/1024:>9.2f} MiB  [{r['category']}] {r['path']}")
    print("\n状态码:", dict(statuses))
    print("方法:", dict(methods))
    if query_keys: print("高频 Query 参数:", query_keys.most_common(15))

if __name__ == "__main__":
    main()
