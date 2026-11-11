#!/usr/bin/env python3
"""Rule-based repair (the paper's R1-R6) for Qwen outputs, all three languages.

This is a thin driver around the authors' own Generation/filter_code.py. Their
`main()` only walks C++ files (documented upstream as a known gap), so this driver
calls the same functions (`process_item` with `clear_generated_code_qwen`) for Python
and Java files too. No repair logic lives here.

Two modes:

  filter   Output/*.jsonl  ->  Filtered_Output/*.jsonl          (fresh generations)
  verify   re-clean the raw `code` stored in the authors' published Filtered_Output
           files and report how often `cleared_code` / `compilable` come out identical.
           This tells you whether the driver reproduces the authors' repair stage.

Usage:
  filter_native.py filter --sallm <clone> [--pattern qwen2.5]
  filter_native.py verify --sallm <clone> --published <dir with published files>
"""
import argparse
import copy
import json
import os
import sys


def load_jsonl(path):
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def contexts(filename):
    low = filename.lower()
    return "java" in low, "cpp" in low


def clean_file(fc, items, filename):
    is_java, is_cpp = contexts(filename)
    out = []
    for item in items:
        item["_is_java_context"] = is_java
        item["_is_cpp_context"] = is_cpp
        res = fc.process_item(item, fc.clear_generated_code_qwen, is_java, is_cpp)
        res.pop("_is_java_context", None)
        out.append(res)
    return out


def cmd_filter(fc, args):
    in_dir = os.path.join(args.sallm, "Generation", "Output")
    out_dir = os.path.join(args.sallm, "Generation", "Filtered_Output")
    os.makedirs(out_dir, exist_ok=True)
    files = sorted(f for f in os.listdir(in_dir)
                   if f.endswith(".jsonl") and args.pattern.lower() in f.lower())
    if not files:
        sys.exit(f"no files matching '{args.pattern}' in {in_dir}")
    for name in files:
        items = clean_file(fc, load_jsonl(os.path.join(in_dir, name)), name)
        total = ok = 0
        for item in items:
            for gens in item.get("generations", {}).values():
                total += len(gens)
                ok += sum(1 for g in gens if g["compilable"])
        with open(os.path.join(out_dir, name), "w", encoding="utf-8") as f:
            for item in items:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")
        rate = 100.0 * ok / total if total else 0.0
        print(f"[filter] {name}: {total} samples, {rate:.1f}% compilable after repair", flush=True)


def cmd_verify(fc, args):
    files = sorted(f for f in os.listdir(args.published)
                   if f.endswith(".jsonl") and args.pattern.lower() in f.lower())
    if not files:
        sys.exit(f"no published files matching '{args.pattern}' in {args.published}")
    worst = 100.0
    for name in files:
        published = load_jsonl(os.path.join(args.published, name))
        if args.langs != "all":
            keep = set(args.langs.split(","))
            for item in published:
                item["generations"] = {k: v for k, v in item["generations"].items() if k in keep}
        raw = copy.deepcopy(published)
        for item in raw:  # back to the shape of an Output/ record: plain strings
            item["generations"] = {k: [g["code"] for g in v] for k, v in item["generations"].items()}
        mine = clean_file(fc, raw, name)
        total = same_code = same_flag = 0
        example = None
        for p_item, m_item in zip(published, mine):
            for lang, p_gens in p_item["generations"].items():
                for p, m in zip(p_gens, m_item["generations"][lang]):
                    total += 1
                    same_code += p["cleared_code"] == m["cleared_code"]
                    same_flag += p["compilable"] == m["compilable"]
                    if example is None and p["cleared_code"] != m["cleared_code"]:
                        example = (p_item["id"], lang, p["cleared_code"], m["cleared_code"])
        pc = 100.0 * same_code / total if total else 0.0
        pf = 100.0 * same_flag / total if total else 0.0
        worst = min(worst, pc)
        print(f"[verify] {name}: {total} samples | cleared_code identical {pc:.2f}% | "
              f"compilable flag identical {pf:.2f}%", flush=True)
        if example and args.show:
            print(f"   first difference: {example[0]} [{example[1]}]\n"
                  f"   --- published ---\n{example[2][:600]}\n   --- reproduced ---\n{example[3][:600]}")
    print(f"[verify] lowest cleared_code agreement: {worst:.2f}%")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["filter", "verify"])
    ap.add_argument("--sallm", required=True, help="path of the SALLM clone")
    ap.add_argument("--pattern", default="qwen2.5", help="substring a file name must contain")
    ap.add_argument("--published", help="verify: directory holding the published Filtered_Output files")
    ap.add_argument("--langs", default="all", help="verify: comma-separated natural languages")
    ap.add_argument("--show", action="store_true", help="verify: print the first differing sample")
    args = ap.parse_args()

    sys.path.insert(0, os.path.join(args.sallm, "Generation"))
    import filter_code as fc  # the authors' repair rules

    if args.command == "filter":
        cmd_filter(fc, args)
    else:
        if not args.published:
            ap.error("verify needs --published")
        cmd_verify(fc, args)


if __name__ == "__main__":
    main()
