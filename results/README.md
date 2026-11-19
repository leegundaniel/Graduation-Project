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
- `security@k` on the authors' outputs is reproduced exactly in 14 of the 15 cells above
  T=0 (the T=0 @3/@5 cells are 0 by construction; the one difference is one prompt).
- `pass@k` is 0.0-4.0 points higher in our environment (never lower), also on the authors'
  outputs, so this offset comes from test execution, not from sampling.
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

| Setting | func@1 | func@10 | func@50 | func-sec@1 | func-sec@10 | func-sec@50 |
|---|---|---|---|---|---|---|
| **Paper**, T=0.8, n=100 (Table I) | 52.62 | 80.54 | 88.34 | 26.53 | 48.70 | 60.31 |
| Ours, T=0.8, top_p 1.0 | 52.44 | 81.91 | 88.91 | 26.89 | 51.32 | 64.93 |
| Ours, T=0.8, top_p 0.9 (model default) | 57.45 | 84.14 | 90.55 | 30.45 | 52.61 | 64.66 |
| **Paper**, greedy (Fig. 3) | 60.50 | | | 33.61 | | |
| Ours, greedy | **60.50** | | | **33.61** | | |

- Greedy decoding reproduces the paper exactly (72/119 functional, 40/119 functional and secure).
- With `top_p` 1.0, func@1 and func-sec@1 are within 0.4 points of the paper. With the model's
  default `top_p` 0.9, the first run was 3.9-4.8 points higher at k=1 (func-sec@1 +3.92,
  func@1 +4.83). The paper does not state `top_p`; this strongly suggests it used 1.0 (the
  API default), and that the unstated parameter alone shifts the headline numbers by 4-5 points.
- At k=10 and k=50 our func-sec values stay 2.6-4.6 points above the paper in both runs, so
  that gap is not explained by `top_p`.
- 183 of 11,900 test results are missing (one sample folder whose test run failed, plus 64
  samples whose test files did not load), so each task has 88-99 tested samples of the 100
  generated. The authors' code leaves such samples out instead
  of counting them as failures. Counting them as failures changes every metric by less than
  0.9 points (`metrics/missing_results_sensitivity.json`).

Contents: `comparison/` both runs' tables, `metrics/` the authors' per-task results
(`res_all_*.json`) and the missing-results check, `logs/` stage logs (pytest output
gzipped), `per_sample_archive.tgz` every raw model response and per-sample test result of
the top_p 1.0 and greedy runs. Per-sample data of the top_p 0.9 run was lost with its
Kaggle session; only its tables survive.
