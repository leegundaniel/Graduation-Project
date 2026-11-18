# Replication results

Free, open-weight replications of two papers in `Thesis/`, run on Kaggle (2x T4) with the
kit in [`replication/`](../replication/README.md). Every number comes from the authors'
own pipeline code at a pinned commit; only the execution environment differs.

## Multi-SALLM, Qwen2.5-Coder-3B-Instruct (Python, English prompts)

Folder: [`multisallm_qwen25coder_python_english/`](multisallm_qwen25coder_python_english/)

| Run | What is tested | Agreement with the paper's released values |
|---|---|---|
| `published` | the authors' own released Qwen generations, re-tested by us | mean difference 1.03 points, largest 4.02 (54 values) |
| `fresh` | new generations from the same model | mean difference 1.70 points, largest 4.80 (54 values) |
| `reference` | the dataset's own insecure reference solutions | 86.4% pass their functional test, 10.4% fail their security test |

- The repair step reproduces the authors' repaired code exactly: `cleared_code` is 100%
  identical in every file (`logs/ms_verify_filter.log`).
- `security@k` on the authors' outputs is reproduced exactly in 16 of 18 cells.
- `pass@k` is 0.5-4 points higher in our environment, also on the authors' outputs, so
  this offset comes from test execution, not from sampling.
- The 17 reference solutions that fail their own functional test need files or packages
  (`assets/`, `static/`, `canvasapi`, `jwt`) that the authors' test images do not
  contain either; this is a property of the dataset.
- Only 10.4% of known-vulnerable reference solutions fail their security test, yet the
  released metric code computes `vul@k` from "security test failed". `vul@k` therefore
  appears to count samples that did *not* show the vulnerability. Reproduced as
  released; worth raising with the authors.

Contents: `comparison/` paper-vs-ours tables, `metrics/` the authors' metric CSVs for each
run, `logs/` stage logs, `per_sample_archive.tgz` every per-sample test outcome plus the
fresh repaired generations.

## CWEval, Llama 3.1 8B Instruct

Folder: [`cweval_llama31_8b/`](cweval_llama31_8b/)

| Setting | func@1 (paper / ours) | func-sec@1 (paper / ours) |
|---|---|---|
| greedy (Fig. 3) | 60.50 / **60.50** | 33.61 / **33.61** |
| T=0.8, n=100, top_p 0.9 (Table I) | 52.62 / 57.45 | 26.53 / 30.45 |
| T=0.8, n=100, top_p 1.0 | 52.62 / pending | 26.53 / pending |

- Greedy decoding reproduces the paper exactly (72/119 and 40/119 tasks).
- At T=0.8 all six metrics are 2-5 points higher. The paper does not state `top_p`; our
  server used the model's default 0.9 (confirmed in the vLLM log). The `top_p` 1.0 run
  tests whether that explains the gap.
- Per-sample outputs of the first run were lost with the Kaggle session; its summary
  tables are in `run1_top_p_0.9.md`.
