#!/usr/bin/env python3
"""Paper-vs-ours tables for a Multi-SALLM run (Qwen2.5-Coder, test-based assessment).

"Paper" = the Qwen rows of the authors' released Evaluation/Result/Tests_Results_*.csv
(copied into paper_targets/). Those per-temperature, per-natural-language numbers are
what the paper's figures and Table 3 are aggregated from.

"Ours" = <run-dir>/Evaluation/Result/Tests_Results_*.csv, written by the authors' own
run_pass_at_k.py on our test results.

The +/- column is a rough 95% sampling band for a fresh generation run: both the paper
and we estimate each number from 125 prompts, so two independent runs of the *same*
model differ by about 2*sqrt(2*p*(1-p)/125). Differences inside the band are what
re-sampling alone produces. For the `published` run (identical code under test) the
band does not apply: differences there come from the evaluation environment only.
"""
import argparse
import csv
import math
import os

METRICS = ["pass@1", "pass@3", "pass@5", "vul@1", "vul@3", "vul@5",
           "security@1", "security@3", "security@5"]
FILES = [("Python", "Tests_Results_Python.csv"), ("Java", "Tests_Results_Java.csv"),
         ("C++", "Tests_Results_Cpp.csv")]


def load(path):
    rows = {}
    if not os.path.exists(path):
        return rows
    with open(path, newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            try:
                key = (r["Model"].lower(), f"{float(r['Temp']):.1f}", r["Language"])
                rows[key] = {m: float(r[m]) for m in METRICS}
            except (KeyError, ValueError):
                continue
    return rows


def band(p_percent):
    p = min(max(p_percent / 100.0, 0.0), 1.0)
    return 100.0 * 2.0 * math.sqrt(2.0 * p * (1.0 - p) / 125.0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--run-dir", required=True)
    ap.add_argument("--targets", required=True)
    ap.add_argument("--name", default="run")
    ap.add_argument("--out")
    args = ap.parse_args()

    lines = [f"# Multi-SALLM, Qwen2.5-Coder-3B-Instruct: paper vs. run `{args.name}`", ""]
    any_rows = False
    for pl, fname in FILES:
        ours = load(os.path.join(args.run_dir, "Evaluation", "Result", fname))
        paper = load(os.path.join(args.targets, fname))
        if not ours:
            continue
        models = sorted({k[0] for k in ours})
        for model in models:
            keys = sorted(k for k in ours if k[0] == model)
            if model == "reference":
                lines += [f"## {pl}: reference (insecure) solutions through the pipeline", "",
                          "| prompts tested | functional test passes | security test fails |",
                          "|---|---|---|"]
                for k in keys:
                    lines.append(f"| {k[2]} | {ours[k]['pass@1']:.1f}% | {ours[k]['vul@1']:.1f}% |")
                lines += ["",
                          "Expected: the functional column close to 100%. The second column is the "
                          "share of *known-vulnerable* solutions whose security test fails; it tells "
                          "you which outcome the released metric code counts (see README).", ""]
                any_rows = True
                continue
            lines += [f"## {pl}", "",
                      "| T | NL | metric | paper | ours | diff | +/- band | inside |",
                      "|---|---|---|---|---|---|---|---|"]
            diffs, inside, total = [], 0, 0
            for k in keys:
                p = paper.get(("qwen2.5", k[1], k[2]))
                if p is None:
                    continue
                for m in METRICS:
                    o, t = ours[k][m], p[m]
                    d = o - t
                    b = band(t)
                    ok = abs(d) <= b
                    diffs.append(abs(d)); total += 1; inside += ok
                    lines.append(f"| {k[1]} | {k[2]} | {m} | {t:.2f} | {o:.2f} | {d:+.2f} | {b:.1f} | "
                                 f"{'yes' if ok else 'NO'} |")
                    any_rows = True
            if diffs:
                lines += ["",
                          f"**{pl} summary:** mean absolute difference {sum(diffs) / len(diffs):.2f} points, "
                          f"largest {max(diffs):.2f}; {inside}/{total} values inside the sampling band.", ""]
    if not any_rows:
        lines.append("No result rows found. Did the evaluation stage finish?")
    text = "\n".join(lines)
    print(text)
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
        print(f"\n[compare] saved {args.out}")


if __name__ == "__main__":
    main()
