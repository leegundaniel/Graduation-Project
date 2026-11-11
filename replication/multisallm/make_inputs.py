#!/usr/bin/env python3
"""Build Filtered_Output inputs for the two GPU-free validation runs.

  reference  One "model output" per prompt = the dataset's own insecure reference
             solution. Running the normal pipeline on it checks the whole evaluation
             environment end to end: functional tests should pass for (almost) every
             prompt, and it shows how the security tests score a known-vulnerable
             solution. No model and no GPU involved.

  published  The authors' released, already-repaired Qwen generations, restricted to
             the chosen natural languages. Re-running the tests on exactly the code
             they tested isolates "is my evaluation environment equivalent to theirs?"
             from sampling randomness.

usage:
  make_inputs.py reference --sallm <clone> --out <Filtered_Output dir> --pls python,cpp,java
  make_inputs.py published --src <dir with published files> --out <Filtered_Output dir> --langs English
"""
import argparse
import json
import os
import sys

PREFIX = {
    "python": ["dataset", "github-dataset"],
    "java": ["dataset_java", "github-dataset_java"],
    "cpp": ["dataset_cpp", "github-dataset_cpp"],
}


def cmd_reference(args):
    os.makedirs(args.out, exist_ok=True)
    for pl in args.pls.split(","):
        for prefix in PREFIX[pl]:
            src = os.path.join(args.sallm, "ProcessedFiles", f"{prefix}_nl_prompt_best.jsonl")
            dst = os.path.join(args.out, f"{prefix}_nl_prompt_best_reference_0.0.jsonl")
            n = 0
            with open(src, encoding="utf-8") as f, open(dst, "w", encoding="utf-8") as out:
                for line in f:
                    if not line.strip():
                        continue
                    d = json.loads(line)
                    code = d["insecure_code"]
                    rec = {k: v for k, v in d.items() if k not in ("translations", "translations_pool")}
                    rec["generations"] = {"English": [{"code": code, "cleared_code": code, "compilable": True}]}
                    out.write(json.dumps(rec, ensure_ascii=False) + "\n")
                    n += 1
            print(f"[inputs] {os.path.basename(dst)}: {n} reference solutions")


def cmd_published(args):
    os.makedirs(args.out, exist_ok=True)
    keep = None if args.langs.lower() == "all" else set(args.langs.split(","))
    for name in sorted(os.listdir(args.src)):
        if not name.endswith(".jsonl"):
            continue
        n = 0
        # normalise the model tag: the authors' C++ files say "Qwen2.5", the others "qwen2.5"
        dst = os.path.join(args.out, name.replace("Qwen2.5", "qwen2.5"))
        with open(os.path.join(args.src, name), encoding="utf-8") as f, open(dst, "w", encoding="utf-8") as out:
            for line in f:
                if not line.strip():
                    continue
                d = json.loads(line)
                if keep is not None:
                    d["generations"] = {k: v for k, v in d["generations"].items() if k in keep}
                d.pop("translations_pool", None)
                n += sum(len(v) for v in d["generations"].values())
                out.write(json.dumps(d, ensure_ascii=False) + "\n")
        print(f"[inputs] {os.path.basename(dst)}: {n} samples ({args.langs})")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)
    r = sub.add_parser("reference")
    r.add_argument("--sallm", required=True)
    r.add_argument("--out", required=True)
    r.add_argument("--pls", default="python")
    p = sub.add_parser("published")
    p.add_argument("--src", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--langs", default="English")
    args = ap.parse_args()
    {"reference": cmd_reference, "published": cmd_published}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
