#!/usr/bin/env python3
"""Print the standards.md ranking table from a benchmark CSV.

    python3 tests/bench-table.py [tests/bench-results/full-1080p.csv]

Rank 0 uses the least (CPU + GPU, then memory), N the most. The z-scores are on
a log scale (log10 of percent + 0.1), since the raw figures are heavily skewed.
"""
import csv, math, os, re, statistics as st, sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "tests/bench-results/full-1080p.csv")
rows = [{"id": r["design"], "cpu": float(r["cpu_pct"]), "gpu": float(r["gpu_pct"]), "rss": float(r["rss_mb"])}
        for r in csv.DictReader(open(path))]

registry = open(os.path.join(root, "Designs.js")).read()
enabled = set(re.findall(r'^\s*\{ id: "([^"]+)", file:', registry, re.M))
LIMIT = {"cpu": 35, "gpu": 10}

def zscores(key):
    logs = [math.log10(r[key] + 0.1) for r in rows]
    m, s = st.mean(logs), st.pstdev(logs)
    return lambda r: (math.log10(r[key] + 0.1) - m) / s
zc, zg = zscores("cpu"), zscores("gpu")

rows.sort(key=lambda r: (r["cpu"] + r["gpu"], r["rss"], r["id"]))
print("| Rank | Design | CPU % | GPU % | MB | CPU z | GPU z | Status |")
print("|---:|---|---:|---:|---:|---:|---:|---|")
for i, r in enumerate(rows):
    over = r["cpu"] > LIMIT["cpu"] or r["gpu"] > LIMIT["gpu"]
    status = ("over limit" if over else "ok") + ("" if r["id"] in enabled else ", disabled")
    print("| %d | %s | %.1f | %.1f | %d | %+.2f | %+.2f | %s |" % (i, r["id"], r["cpu"], r["gpu"], r["rss"], zc(r), zg(r), status))
