#!/usr/bin/env python3
"""Aggregate coverage at 9h across all cov_log_*.txt files.

Walks server_runs/ and reports geomean per (core, config) at the
9-hour wall-clock mark, matching the methodology in the report.
"""
import glob, math, os
from collections import defaultdict

NINE_H = 32400      # seconds
MIN_FINAL = 22000   # drop runs that died before ~6.1h

def parse(dirname):
    core = "rocket" if "rocket" in dirname else ("boom" if "boom" in dirname else None)
    if "powrate" in dirname:                          cfg = "powrate"
    elif "pow" in dirname:                            cfg = "pow"
    elif "evict" in dirname:                          cfg = "evict"
    elif "random" in dirname or "nogu" in dirname:    cfg = "nogu"
    elif "baseline" in dirname or "guided" in dirname: cfg = "baseline"
    else:                                             cfg = None
    return core, cfg

def geomean(vs):
    return math.exp(sum(math.log(v) for v in vs) / len(vs))

data = defaultdict(list)
skipped = []
for f in glob.glob("server_runs/**/cov_log*.txt", recursive=True):
    rd = os.path.basename(os.path.dirname(f))
    core, cfg = parse(rd)
    if not core or not cfg:
        continue
    cov, last_t = None, 0.0
    with open(f) as fp:
        for line in fp:
            parts = line.split()
            if len(parts) < 3: continue
            try: t = float(parts[0])
            except: continue
            last_t = t
            if t <= NINE_H:
                try: cov = int(parts[2])
                except: pass
    if cov is None or last_t < MIN_FINAL:
        skipped.append(f)
        continue
    data[(core, cfg)].append(cov)

print(f"\n{'Core':<8}{'Config':<10}{'n':<4}{'GeoMean':<12}{'Min':<10}{'Max':<10}{'vs base':>10}")
print("-" * 64)
for core in ("rocket", "boom"):
    base = data.get((core, "baseline"))
    base_g = geomean(base) if base else None
    for cfg in ("nogu", "baseline", "pow", "powrate", "evict"):
        vs = data.get((core, cfg))
        if not vs: continue
        g = geomean(vs)
        delta = (g - base_g) / base_g * 100 if base_g else 0
        sign = "+" if delta >= 0 else ""
        marker = "" if cfg == "baseline" else f"{sign}{delta:.2f}%"
        print(f"{core:<8}{cfg:<10}{len(vs):<4}{g:>10,.0f}  "
              f"{min(vs):<10,}{max(vs):<10,}{marker:>10}")
    print()

if skipped:
    print(f"({len(skipped)} runs skipped: incomplete or unparseable)")
