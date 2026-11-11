# Replication kit: CWEval and Multi-SALLM with free, open-weight models

Goal: re-run the published methodology of two papers with models that cost nothing to
run, and compare our numbers with the papers' numbers.

| Paper | Model replicated here | Paper numbers we compare against |
|---|---|---|
| CWEval (Peng et al., arXiv:2501.08200) | Llama 3.1 8B Instruct | Table I row and Fig. 3 bars |
| Multi-SALLM (Siddiq et al., ASE journal 2026) | Qwen2.5-Coder-3B-Instruct | the Qwen rows of the authors' released result CSVs (what Figs. 7-9, 14-19 and Table 3 are built from) |

Both pipelines run the **authors' own code** from their public replication packages,
pinned to a fixed commit. This kit only adds what is needed to run them on Kaggle,
which has GPUs but no Docker.

> **Status.** The kit was written and reviewed against the authors' code, and the parts
> that are our own code (generation client, comparison tables) were tested against a
> mock model server. It has **not yet been run end to end**: that needs a GPU and
> needs to execute the benchmarks' deliberately vulnerable code, neither of which was
> possible where the kit was written. Each pipeline therefore starts with GPU-free
> self-checks (below). Treat the first Kaggle session as a shake-down.

## What is and is not changed relative to the papers

| Stage | CWEval | Multi-SALLM |
|---|---|---|
| Tasks / prompts | authors' benchmark, unchanged (119 tasks) | authors' prompt files, unchanged (125 prompts x 3 languages x 23 natural languages) |
| Prompt wording | authors' `generate.py` | copied from the authors' generation scripts |
| Model | same open weights, self-hosted (vLLM, float16) instead of a hosted API | same open weights, self-hosted instead of HF pipeline / HF router |
| Sampling | n=100 at T=0.8, plus greedy | 10 samples at T=0.0-1.0, 2048 tokens |
| Output repair | authors' `evaluate.py` | authors' `filter_code.py` functions |
| Test execution | authors' oracles, **natively instead of in their Docker image** | authors' runner, **native stand-in for their Apptainer images** |
| Metrics | authors' `evaluate.py` | authors' `run_test_evaluation.py`, `run_pass_at_k.py` |

Not included yet: Multi-SALLM's CodeQL (static) assessment, and the other three models
of each paper. Multi-SALLM defaults to English prompts in Python; other languages are a
setting (`PLS`, `LANGS`), because the full grid is about 517,000 generations and as many
test runs.

## Running on Kaggle

The professor's suggestion (VS Code tunnel into a Kaggle notebook) works with this kit:
everything is plain shell scripts.

1. Open <https://www.kaggle.com/code/omidostovari/kaggle-vscode-remote-tunnel>, choose
   **Copy & Edit**. In the notebook settings turn **Internet on** and set
   **Accelerator: GPU T4 x2**. Run it and connect VS Code as the notebook describes.
2. In the VS Code terminal:

   ```bash
   cd /kaggle/working
   git clone -b claude/intelligent-noether-sgvujq https://github.com/leegundaniel/Graduation-Project.git
   cd Graduation-Project/replication
   ```

3. Follow the two sections below. Results land in
   `/kaggle/working/replication_work/results/*.md`.

Things to know about Kaggle:

- A session lasts at most 12 hours and GPU time is capped per week (30 h at the time of
  writing). An interactive session also stops when it sits idle. Everything under
  `/kaggle/working` disappears with the session unless you download it. Before a
  session ends: `tar czf /kaggle/working/results.tgz -C /kaggle/working/replication_work results runs`
  and download the file.
- Only the *generation* stages need the GPU. The test stages are CPU-only, so you can
  generate in a GPU session, download `runs/`, and evaluate later in a CPU session (or
  on your MacBook/PC, where Docker is available and the authors' original containers
  can be used instead).
- For long unattended runs, `notebooks/kaggle_batch.ipynb` does the same steps as a
  notebook you start with **Save Version -> Save & Run All**, which keeps running with
  the browser closed.
- Generated code and the benchmarks' reference exploits run directly on the Kaggle VM.
  That VM is disposable, which is the reason this is acceptable there. Do not run the
  native (no-container) test stages on your own machine; use Docker there.

### Model access

- **Qwen2.5-Coder-3B-Instruct** is not gated; nothing to do.
- **Llama 3.1 8B Instruct** is gated: accept Meta's licence on
  <https://huggingface.co/meta-llama/Meta-Llama-3.1-8B-Instruct>, create a read token,
  and `export HF_TOKEN=hf_...` before starting the server (use a Kaggle Secret rather
  than typing it into a saved notebook). If approval is slow,
  `export LLAMA_MODEL=unsloth/Meta-Llama-3.1-8B-Instruct` points at an ungated re-upload
  of the same weights; say so in the write-up if you use it.

## CWEval (Llama 3.1 8B Instruct)

```bash
cweval/setup.sh                      # ~15 min. Ends by testing all reference solutions.
common/serve_vllm.sh start llama     # downloads the model, starts the server
cweval/run.sh generate               # T=0.8 with n=100, and greedy
common/serve_vllm.sh stop
cweval/run.sh evaluate               # CPU only
cweval/run.sh compare
```

`setup.sh` must end with every reference test passing; that is the authors' own check
that an environment is equivalent to their Docker image. If it does not, stop there.

Targets (paper, Llama 3.1 8B Instruct):

| setting | func@1 | func@10 | func@50 | func-sec@1 | func-sec@10 | func-sec@50 |
|---|---|---|---|---|---|---|
| T=0.8, n=100 (Table I) | 52.62 | 80.54 | 88.34 | 26.53 | 48.70 | 60.31 |
| greedy (Fig. 3) | 60.50 | | | 33.61 | | |

Smaller first run: `N=20 cweval/run.sh generate` (the authors' README says n >= 2k is
enough for pass@k, so n=20 supports k=1 and k=10).

## Multi-SALLM (Qwen2.5-Coder-3B-Instruct)

```bash
multisallm/setup.sh                  # PLS="python cpp java" multisallm/setup.sh for more languages

# GPU-free checks, in this order
multisallm/run.sh refcheck           # reference solutions through the whole pipeline
multisallm/run.sh verify-filter      # do we reproduce the authors' repaired outputs?
multisallm/run.sh published          # re-test the authors' own Qwen generations

# fresh generations
common/serve_vllm.sh start qwen
multisallm/run.sh generate
common/serve_vllm.sh stop
multisallm/run.sh evaluate           # prints the paper-vs-ours table at the end
```

Scope is set with environment variables, for example
`PLS="python cpp" LANGS="English,German,Chinese" TEMPS="0.2,0.8" multisallm/run.sh generate`.

The three checks answer different questions, and together they are the argument to
show the professor:

| run | same code under test as the authors? | a difference means |
|---|---|---|
| `refcheck` | their reference solutions | our environment cannot run their tests |
| `verify-filter` | their raw outputs | our repair step differs from theirs |
| `published` | their repaired Qwen outputs | our test environment differs from their containers (this run *should* match the paper almost exactly) |
| `generate` + `evaluate` | new samples from the same model | sampling randomness, plus the generation details below |

## What the released artifacts show (worth reporting)

Reading the authors' code and released outputs turned up several things that the papers
do not state and that bound how exactly their numbers can be reproduced. Items 1-4 are
facts about the released files; item 5 is a reading of the code that the `refcheck` run
is designed to confirm.

1. **Multi-SALLM's Qwen outputs were produced in two different ways.** The released
   Python outputs contain `<|/assistant|>` pseudo-tags (53-87% of samples depending on
   temperature) and exactly one sample per prompt at T=0. That matches the local
   Hugging Face recipe in `Huggingface_model.py` (plain-text `<|system|>/<|user|>/<|assistant|>`
   prompt, not Qwen's chat template). The Java and C++ outputs have no such tags and ten
   samples at T=0, matching `qwen_model.py` (chat API through the Hugging Face router).
   `generate.py` in this kit follows the same split.
2. **"Temperature 0" is not deterministic in the Java/C++ data.** `qwen_model.py` sends
   temperature 1e-4, yet only 428 of 2,278 (Java) and 652 of 2,300 (C++) prompt/language
   cells have ten identical samples. The hosted endpoint evidently added randomness. A
   self-hosted model at 1e-4 returns ten near-identical samples, so T=0.0 rows for Java
   and C++ cannot be matched closely; compare T >= 0.2.
3. **Python T=0 has n=1**, so the released pass@3, pass@5, vul@3/5 and security@3/5 for
   Qwen/Python at T=0 are 0.00 by construction, not measurements.
4. **System prompt quirk.** The generation scripts take the language name from a
   `main_path` field that only Java records have, so Python and C++ prompts were sent as
   "You are an expert programmer and understand Programming Language." Reproduced as is.
5. **`vulnerable@k` and `security@k` are computed from the same per-sample flag.** In
   `run_pass_at_k.py` both use `test_vulnerability == 'failure'`: vulnerable@k is "at
   least one of k samples has it", security@k is "the first k samples all have it". The
   dataset's security tests assert the *vulnerable* behaviour (for example
   `assertEqual(match_string('xXy.z'), True)  # Vulnerability: ...`), so a failing
   security test appears to mean the sample did **not** show the vulnerability, while
   the paper text defines a sample whose security test fails as vulnerable. If
   `refcheck` shows the known-vulnerable reference solutions *passing* their security
   tests, then the released `vul@k` counts non-vulnerable samples. This kit reproduces
   the released computation unchanged so numbers stay comparable; the interpretation is
   a question for the authors.
6. **CWEval does not say where Llama 3.1 8B was hosted** or which sampling parameters
   besides temperature were used. We use Meta's published defaults (top_p 0.9) at
   float16. A hosted, possibly quantised endpoint can differ by a few points.

## How close should the numbers be?

Fresh generations are new random samples, so exact equality is not expected. Each
comparison table carries a rough 95% band for two independent runs of the same model
(about 6-9 points for Multi-SALLM's 125 prompts, 8-13 points for CWEval's 119 tasks) and
marks each value inside or outside it. The `published` run has no sampling at all and
is the place to expect near-exact agreement.

## About Gemini and ChatGPT subscriptions

Gemini Plus and ChatGPT Pro are app subscriptions; neither includes API usage, which is
what both pipelines need. The one model both papers share is **GPT-4o mini** (CWEval
pins `gpt-4o-mini-2024-07-18`); running it needs paid OpenAI API credit, a few dollars
for the scopes above, provided that snapshot is still served. Gemini 2.5 Flash
(Multi-SALLM only) has a free API tier through Google AI Studio with daily limits that
suit the English-only scope. Both are optional follow-ups; the authors' scripts for them
(`gpt_model.py`, `gemini_model.py`, CWEval's `--model`) work as documented upstream.

## Layout

```
common/env.sh            pinned commits, model names, work folder
common/serve_vllm.sh     start/stop the local model server
cweval/setup.sh          native equivalent of the authors' Dockerfile + their sanity test
cweval/run.sh            generate / evaluate / compare
cweval/compare.py        paper-vs-ours table (paper_targets.json)
multisallm/setup.sh      clone, prompt files, test environment, toolchains
multisallm/run.sh        refcheck / verify-filter / published / generate / evaluate / compare
multisallm/generate.py   generation client reproducing the authors' two paths
multisallm/filter_native.py  driver for the authors' repair rules (all three languages)
multisallm/make_inputs.py    inputs for the refcheck and published runs
multisallm/tools/apptainer   native stand-in for the authors' per-prompt containers
multisallm/compare.py    paper-vs-ours tables (paper_targets/*.csv, from the authors' package, Apache-2.0)
notebooks/kaggle_batch.ipynb  the same steps as an unattended Kaggle notebook
```
