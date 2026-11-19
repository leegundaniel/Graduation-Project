# CWEval, Llama 3.1 8B Instruct: paper vs. ours

## t0.8p1: Table I (random sampling, n=100, temperature 0.8); ours with top_p=1.0

Ours: 119 tasks, 100 samples generated per task; 88-99 per task have a test result
(183 of 11,900 missing, see results/README.md).

| metric | paper | ours | diff | +/- band | inside |
|---|---|---|---|---|---|
| func@1 | 52.62 | 52.44 | -0.18 | 12.9 | yes |
| func@10 | 80.54 | 81.91 | +1.37 | 10.3 | yes |
| func@50 | 88.34 | 88.91 | +0.57 | 8.3 | yes |
| func-sec@1 | 26.53 | 26.89 | +0.36 | 11.4 | yes |
| func-sec@10 | 48.70 | 51.32 | +2.62 | 13.0 | yes |
| func-sec@50 | 60.31 | 64.93 | +4.62 | 12.7 | yes |

## greedy: Fig. 3 (greedy decoding, func@1* and func-sec@1*)

Ours: 119 tasks, n=1 samples per task.

| metric | paper | ours | diff | +/- band | inside |
|---|---|---|---|---|---|
| func@1 | 60.50 | 60.50 | +0.00 | 12.7 | yes |
| func-sec@1 | 33.61 | 33.61 | +0.00 | 12.2 | yes |

