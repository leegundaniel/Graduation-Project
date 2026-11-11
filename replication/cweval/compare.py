#!/usr/bin/env python3
"""Paper-vs-ours table for CWEval (Llama 3.1 8B Instruct).

Reads <evals>/llama31_8b_<config>/res_all.json, which the authors' evaluate.py writes,
and recomputes func@k / func-sec@k with the same unbiased pass@k estimator they use
(cweval/commons.py: pass_at_k), averaged over the 119 tasks.

The +/- column is a rough 95% band for two independent runs of the same model over 119
tasks, 2*sqrt(2*p*(1-p)/119). It ignores that tasks differ in difficulty, so read it as
an order of magnitude, not a test.
"""
import argparse
import json
import math
import os


def pass_at_k(n, c, k):
    if n - c < k:
        return 1.0
    prod = 1.0
    for i in range(n - c + 1, n + 1):
        prod *= 1.0 - k / i
    return 1.0 - prod


def metrics(res_all):
    n = len(next(iter(res_all.values()))["functional"])
    out = {"n": n, "tasks": len(res_all)}
    for k in (1, 10, 50):
        if n < k:
            continue
        f = [pass_at_k(len(r["functional"]), sum(r["functional"]), k) for r in res_all.values()]
        fs = [pass_at_k(len(r["func_secure"]), sum(r["func_secure"]), k) for r in res_all.values()]
        out[f"func@{k}"] = 100.0 * sum(f) / len(f)
        out[f"func-sec@{k}"] = 100.0 * sum(fs) / len(fs)
    return out


def band(p_percent, tasks=119):
    p = min(max(p_percent / 100.0, 0.0), 1.0)
    return 100.0 * 2.0 * math.sqrt(2.0 * p * (1.0 - p) / tasks)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--evals", required=True)
    ap.add_argument("--targets", required=True)
    ap.add_argument("--out")
    args = ap.parse_args()

    with open(args.targets, encoding="utf-8") as f:
        targets = json.load(f)
    lines = ["# CWEval, Llama 3.1 8B Instruct: paper vs. ours", ""]
    ours = {}
    for name in sorted(os.listdir(args.evals)):
        path = os.path.join(args.evals, name, "res_all.json")
        if name.startswith("llama31_8b_") and os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                ours[name[len("llama31_8b_"):]] = metrics(json.load(f))
    if not ours:
        lines.append("No res_all.json found. Did `run.sh evaluate` finish?")

    for cfg in ("t0.8", "greedy"):
        if cfg not in ours:
            continue
        m, t = ours[cfg], targets[cfg]
        lines += [f"## {cfg}: {t['where']}", "",
                  f"Ours: {m['tasks']} tasks, n={m['n']} samples per task.", "",
                  "| metric | paper | ours | diff | +/- band | inside |", "|---|---|---|---|---|---|"]
        for key in ("func@1", "func@10", "func@50", "func-sec@1", "func-sec@10", "func-sec@50"):
            if key not in t or key not in m:
                continue
            d = m[key] - t[key]
            b = band(t[key])
            lines.append(f"| {key} | {t[key]:.2f} | {m[key]:.2f} | {d:+.2f} | {b:.1f} | "
                         f"{'yes' if abs(d) <= b else 'NO'} |")
        if m["tasks"] != targets["tasks"]:
            lines.append(f"\nNote: {m['tasks']} tasks evaluated, the paper has {targets['tasks']}.")
        lines.append("")

    temps = {c: m for c, m in ours.items() if c.startswith("t") and "func@10" in m}
    if len(temps) > 1:
        t = targets["best_of_temperatures"]
        lines += [f"## Best over temperatures: {t['where']}", "",
                  "| metric | paper | ours (best) | at |", "|---|---|---|---|"]
        for key in ("func@10", "func-sec@10"):
            best = max(temps, key=lambda c: temps[c][key])
            lines.append(f"| {key} | {t[key]:.2f} | {temps[best][key]:.2f} | {best} |")
        lines.append("")

    text = "\n".join(lines)
    print(text)
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
        print(f"\n[compare] saved {args.out}")


if __name__ == "__main__":
    main()
