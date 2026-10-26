#!/usr/bin/env python3
"""
Marketing Watch — snapshot a list of websites and report what changed since the last run.
Part of the AI Marketing Suite (Hermes Agent skills). Python stdlib only.

Usage:
  python3 watch.py <watchlist.txt> <state_dir>

watchlist.txt: one URL per line; blank lines and lines starting with # are ignored.
               Optional label: "Label | https://example.com".
state_dir:     where snapshots are stored (<state_dir>/<slug>/<YYYY-MM-DD>.json).

Prints a JSON report: one entry per URL with the changed fields (before/after).
"""

import json
import os
import sys
from datetime import date
from urllib.parse import urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyze_page  # noqa: E402
import competitor_scanner  # noqa: E402

LIST_LIMIT = 10


def slugify(url):
    host = urlparse(url).netloc.lower()
    if host.startswith("www."):
        host = host[4:]
    return host.replace(".", "-").replace(":", "-") or "unknown"


def texts(items):
    out = []
    for item in items or []:
        text = item.get("text") if isinstance(item, dict) else str(item)
        if text and text not in out:
            out.append(text.strip())
    return out[:LIST_LIMIT]


def snapshot(url):
    page = analyze_page.analyze(url)
    if page.get("status") != "success":
        return {"status": "error", "error": page.get("message", "fetch failed")}
    a = page["analysis"]
    comp = competitor_scanner.scan_competitor(url)
    pricing = comp.get("data", {}).get("pricing", {}) if comp.get("status") == "success" else {}
    return {
        "status": "success",
        "title": a["seo"]["title"],
        "meta_description": a["seo"]["meta_description"],
        "h1": a["content"]["h1"][:LIST_LIMIT],
        "h2": a["content"]["h2"][:LIST_LIMIT],
        "ctas": texts(a["conversion"]["ctas"]),
        "form_count": a["conversion"]["form_count"],
        "social_links": sorted({s.get("platform", "") for s in a["trust"]["social_links"]}),
        "tracking_tools": sorted(a["tracking"]["tools_detected"]),
        "schema_types": sorted(str(t) for t in a["tracking"]["schema_types"]),
        "pricing_mentions": (pricing.get("pricing_mentions") or [])[:LIST_LIMIT],
        "word_count": a["content"]["word_count"],
        "overall_score": a["overall_score"],
    }


def latest_previous(folder, today):
    if not os.path.isdir(folder):
        return None, None
    files = sorted(f for f in os.listdir(folder) if f.endswith(".json") and f[:-5] < today)
    if not files:
        return None, None
    path = os.path.join(folder, files[-1])
    with open(path, encoding="utf-8") as f:
        return json.load(f), files[-1][:-5]


def diff(before, after):
    changes = []
    for key, new in after.items():
        old = before.get(key)
        if old == new:
            continue
        if key == "word_count" and old and abs(new - old) / max(old, 1) < 0.1:
            continue
        change = {"field": key, "before": old, "after": new}
        if isinstance(old, list) and isinstance(new, list):
            change = {"field": key, "added": [x for x in new if x not in old], "removed": [x for x in old if x not in new]}
        changes.append(change)
    return changes


def read_watchlist(path):
    entries = []
    with open(os.path.expanduser(path), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            label, _, url = line.rpartition("|")
            url = url.strip()
            if not url.startswith("http"):
                url = "https://" + url
            entries.append({"label": label.strip() or slugify(url), "url": url})
    return entries


def main():
    if len(sys.argv) < 3:
        print(json.dumps({"usage": "python3 watch.py <watchlist.txt> <state_dir>"}, indent=2))
        sys.exit(1)
    watchlist, state_dir = sys.argv[1], os.path.abspath(os.path.expanduser(sys.argv[2]))
    if not os.path.isfile(os.path.expanduser(watchlist)):
        print(json.dumps({"status": "error", "error": f"watchlist not found: {watchlist}"}))
        sys.exit(1)

    today = date.today().isoformat()
    report = {"date": today, "sites": []}
    for entry in read_watchlist(watchlist):
        folder = os.path.join(state_dir, slugify(entry["url"]))
        snap = snapshot(entry["url"])
        item = dict(entry)
        if snap["status"] != "success":
            item.update(status="error", error=snap["error"])
            report["sites"].append(item)
            continue
        previous, prev_date = latest_previous(folder, today)
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, today + ".json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(snap, f, ensure_ascii=False, indent=2)
        item.update(status="success", snapshot=path, overall_score=snap["overall_score"])
        if previous is None:
            item.update(first_run=True, changes=[])
        else:
            item.update(first_run=False, compared_to=prev_date, changes=diff(previous, snap))
        report["sites"].append(item)

    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
