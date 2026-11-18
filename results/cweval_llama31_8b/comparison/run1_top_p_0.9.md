# CWEval, Llama 3.1 8B Instruct: first full run (Kaggle, 2026-11-17)

Model: `meta-llama/Meta-Llama-3.1-8B-Instruct` (official gated weights), served with vLLM,
float16, 2x T4. Pipeline: authors' CWEval code at commit e9a2a12, run natively
(`replication/cweval`). Reference-solution sanity check passed before generation.

Sampling: the server applied the model's `generation_config.json`
(`top_p` 0.9; temperature overridden by each request), confirmed from the vLLM log:
"Default vLLM sampling parameters have been overridden by the model's
generation_config.json: {'temperature': 0.6, 'top_p': 0.9}".

Only these summary tables survive: the Kaggle session ended before the per-sample
outputs and test results were downloaded.

## T=0.8, n=100 (paper: Table I)

| metric | paper | ours | diff |
|---|---|---|---|
| func@1 | 52.62 | 57.45 | +4.83 |
| func@10 | 80.54 | 84.14 | +3.60 |
| func@50 | 88.34 | 90.55 | +2.21 |
| func-sec@1 | 26.53 | 30.45 | +3.92 |
| func-sec@10 | 48.70 | 52.61 | +3.91 |
| func-sec@50 | 60.31 | 64.66 | +4.35 |

## Greedy, n=1 (paper: Fig. 3, func@1* and func-sec@1*)

| metric | paper | ours | diff |
|---|---|---|---|
| func@1 | 60.50 | 60.50 | +0.00 |
| func-sec@1 | 33.61 | 33.61 | +0.00 |

## Reading

- Greedy decoding reproduces the paper exactly (72/119 functional, 40/119 functional and
  secure). Greedy has no randomness, so model, prompts, oracles and metrics agree.
- At T=0.8 every metric is 2-5 points higher. With 100 samples per task over the same 119
  tasks, sampling noise is well under a point, so this is a systematic difference.
- Hypothesis: `top_p`. The paper and CWEval's code do not set it; we ran with the model
  default 0.9, while a hosted API defaults to 1.0. A lower top_p reduces randomness and
  raises pass rates, and does not affect greedy decoding, matching the pattern above.
  Test pending: `CONFIGS=t0.8p1` (same settings with top_p=1.0).
