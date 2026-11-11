#!/usr/bin/env python3
"""Multi-SALLM code generation for Qwen2.5-Coder-3B-Instruct against a local
OpenAI-compatible server (vLLM), reproducing the authors' two generation paths.

Why two paths? The authors' released Qwen outputs were not all produced the same way
(see README, "What the released artifacts show"):

  raw   Python outputs carry `<|/assistant|>` pseudo-tags and have exactly ONE sample at
        temperature 0. That is the signature of the local Hugging Face recipe in
        Generation/Huggingface_model.py: a plain-text prompt
            <|system|>\\n{system}\\n<|user|>\\n{prompt}\\n<|assistant|>\\n
        sampled with temperature=T, top_p=1.0, 10 return sequences, 2048 new tokens
        (greedy and a single sequence at T=0).
  chat  Java and C++ outputs have no pseudo-tags and ten samples even at T=0. That is
        Generation/qwen_model.py: a chat completion (system + user message) with
        n=10, top_p=1.0, max_tokens=2048 and temperature=max(T, 1e-4).

By default each programming language uses the path its released outputs show
(python -> raw, java/cpp -> chat). `--mode` overrides that.

Prompt construction (system message, docstring replacement for translated prompts,
the `main_path`-based language name) is copied from the authors' scripts, including
the quirk that only Java records carry `main_path`, so Python and C++ prompts say
"understand Programming Language".

Output: <out-dir>/<input-stem>_qwen2.5_<T>.jsonl with the same record layout as the
authors' Generation/Output files, so their filtering and evaluation scripts consume it
unchanged. A per-request cache next to the output makes the run resumable.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

TEMPERATURES = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
MAX_TOKENS = 2048
N_SAMPLES = 10


# --- copied from s2e-lab/SALLM Generation/qwen_model.py (Apache-2.0) -------------------
def extract_docstring_range(code):
    docstring_pattern = r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|/\*\*?[\s\S]*?\*/'
    match = re.search(docstring_pattern, code)
    if match:
        start, end = match.span()
        original = match.group(0)
        last_newline = code.rfind('\n', 0, start)
        if last_newline == -1:
            indent = ""
        else:
            indent = code[last_newline + 1:start]
            if not indent.strip() == "":
                indent = ""
        return start, end, original, indent
    return None


def replace_docstring(code, new_docstring):
    match_info = extract_docstring_range(code)
    if not match_info:
        return code
    start, end, original, indent = match_info
    if original.startswith('"""'):
        replacement = f'"""\n{new_docstring}\n{indent}"""'
    elif original.startswith("'''"):
        replacement = f"'''\n{new_docstring}\n{indent}'''"
    elif original.startswith("/*"):
        is_javadoc = original.startswith("/**")
        start_marker = "/**" if is_javadoc else "/*"
        end_marker = " */"
        lines = new_docstring.split('\n')
        formatted_lines = [f"{indent} * {line}" for line in lines]
        replacement = f"{start_marker}\n" + "\n".join(formatted_lines) + f"\n{indent}{end_marker}"
    else:
        replacement = new_docstring
    return code[:start] + replacement + code[end:]


def language_name(item, mode):
    """Language string for the system message, exactly as the authors derive it."""
    file_ext = os.path.splitext(item.get('main_path', ''))[-1].lower()
    if '.py' in file_ext:
        return "Python"
    if '.java' in file_ext:
        return "Java"
    # qwen_model.py also maps C++ extensions; Huggingface_model.py does not. Neither
    # ever fires for C++ or Python records because those have no `main_path`.
    if mode == "chat" and any(ext in file_ext for ext in ['.cpp', '.cc', '.cxx', '.h', '.hpp']):
        return "C++"
    return "Programming Language"


def system_message(language):
    return (f"You are an expert programmer and understand {language}. "
            "Only output the code without any explanation.")
# ---------------------------------------------------------------------------------------


class Cache:
    """Append-only JSONL cache of finished requests (survives a killed session)."""

    def __init__(self, path):
        self.path, self.lock, self.data = path, threading.Lock(), {}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                for line in f:
                    try:
                        rec = json.loads(line)
                        self.data[rec["key"]] = rec["outputs"]
                    except Exception:
                        pass  # truncated last line of an interrupted run
        self.fh = open(path, "a", encoding="utf-8")

    def get(self, key):
        return self.data.get(key)

    def put(self, key, outputs):
        with self.lock:
            self.data[key] = outputs
            self.fh.write(json.dumps({"key": key, "outputs": outputs}, ensure_ascii=False) + "\n")
            self.fh.flush()


def request(client, args, mode, prompt_text, language, temp):
    """One prompt -> list of raw completions, following the chosen authors' path."""
    if mode == "raw":
        full_prompt = f"<|system|>\n{system_message(language)}\n<|user|>\n{prompt_text}\n<|assistant|>\n"
        greedy = temp == 0.0
        resp = client.completions.create(
            model=args.model,
            prompt=full_prompt,
            temperature=0.0 if greedy else temp,
            top_p=1.0,
            max_tokens=MAX_TOKENS,
            n=1 if greedy else N_SAMPLES,
        )
        return [c.text.strip() for c in resp.choices]
    api_temp = max(1e-4, temp) if temp < 1e-4 else temp
    resp = client.chat.completions.create(
        model=args.model,
        messages=[
            {"role": "system", "content": system_message(language)},
            {"role": "user", "content": prompt_text + '\n'},
        ],
        temperature=api_temp,
        max_tokens=MAX_TOKENS,
        top_p=1.0,
        n=N_SAMPLES,
    )
    return [(c.message.content or "").strip() for c in resp.choices]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", help="ProcessedFiles/<prefix>_nl_prompt_best.jsonl")
    ap.add_argument("--out-dir", required=True, help="the SALLM clone's Generation/Output")
    ap.add_argument("--model", default=os.environ.get("QWEN_MODEL", "Qwen/Qwen2.5-Coder-3B-Instruct"))
    ap.add_argument("--api-base", default=f"http://localhost:{os.environ.get('VLLM_PORT', '8000')}/v1")
    ap.add_argument("--api-key", default=os.environ.get("OPENAI_API_KEY", "EMPTY"))
    ap.add_argument("--mode", choices=["auto", "raw", "chat"], default="auto")
    ap.add_argument("--langs", default="English",
                    help="comma-separated natural languages, or 'all' for the paper's 23")
    ap.add_argument("--temps", default=",".join(str(t) for t in TEMPERATURES))
    ap.add_argument("--workers", type=int, default=32, help="concurrent requests to the server")
    ap.add_argument("--limit", type=int, default=0, help="only the first N prompts (smoke test)")
    ap.add_argument("--tag", default="qwen2.5", help="model tag used in output file names")
    args = ap.parse_args()

    from openai import OpenAI
    client = OpenAI(base_url=args.api_base, api_key=args.api_key, timeout=1800, max_retries=3)

    stem = os.path.splitext(os.path.basename(args.input))[0]
    mode = args.mode
    if mode == "auto":
        mode = "chat" if ("_java_" in stem or "_cpp_" in stem) else "raw"

    with open(args.input, encoding="utf-8") as f:
        data = [json.loads(line) for line in f if line.strip()]
    if data and "prompt" not in data[0]:
        sys.exit(f"{args.input} does not look like a prompt file (still a Git LFS pointer?)")
    if args.limit:
        data = data[:args.limit]

    wanted = None if args.langs.lower() == "all" else [s.strip() for s in args.langs.split(",") if s.strip()]
    temps = [float(t) for t in args.temps.split(",")]
    os.makedirs(args.out_dir, exist_ok=True)
    print(f"[generate] {stem}: {len(data)} prompts, mode={mode}, langs={args.langs}, temps={temps}", flush=True)

    for temp in temps:
        out_file = os.path.join(args.out_dir, f"{stem}_{args.tag}_{temp}.jsonl")
        if os.path.exists(out_file):
            print(f"[generate] {out_file} exists, skipping", flush=True)
            continue
        cache = Cache(out_file + ".cache")

        jobs = []  # (item index, language key, prompt text, language name)
        for idx, item in enumerate(data):
            lang_name = language_name(item, mode)
            original = item.get("prompt", "")
            if wanted is None or "English" in wanted:
                jobs.append((idx, "English", original, lang_name))
            for target, trans in item.get("translations", {}).items():
                if wanted is not None and target not in wanted:
                    continue
                if isinstance(trans, dict) and "translation" in trans:
                    jobs.append((idx, target, replace_docstring(original, trans["translation"]), lang_name))

        def work(job):
            idx, lang_key, prompt_text, lang_name = job
            key = hashlib.sha1(f"{mode}|{args.model}|{temp}|{lang_name}|{prompt_text}".encode()).hexdigest()
            hit = cache.get(key)
            if hit is not None:
                return idx, lang_key, hit, False
            try:
                outputs = request(client, args, mode, prompt_text, lang_name, temp)
            except Exception as e:  # the authors' script records this placeholder on failure
                print(f"[generate] ERROR {data[idx].get('id')} {lang_key}: {e}", flush=True)
                return idx, lang_key, ['Problem occurred.'] * N_SAMPLES, True
            cache.put(key, outputs)
            return idx, lang_key, outputs, False

        results = [dict() for _ in data]
        errors, done, t0 = 0, 0, time.time()
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            for fut in as_completed([ex.submit(work, j) for j in jobs]):
                idx, lang_key, outputs, failed = fut.result()
                results[idx][lang_key] = outputs
                errors += failed
                done += 1
                if done % 50 == 0 or done == len(jobs):
                    print(f"[generate] T={temp}: {done}/{len(jobs)} prompts "
                          f"({time.time() - t0:.0f}s, {errors} errors)", flush=True)

        if errors:
            print(f"[generate] T={temp}: {errors} requests failed; NOT writing {out_file}. "
                  "Fix the server and re-run (finished requests are cached).", flush=True)
            sys.exit(1)

        with open(out_file, "w", encoding="utf-8") as out_f:
            for item, gens in zip(data, results):
                rec = dict(item)
                # keep the language order of the authors' files: English first
                rec["generations"] = {k: gens[k] for k in (["English"] + list(item.get("translations", {})))
                                      if k in gens}
                out_f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        print(f"[generate] wrote {out_file}", flush=True)


if __name__ == "__main__":
    main()
