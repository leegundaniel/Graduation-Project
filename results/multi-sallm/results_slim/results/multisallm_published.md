# Multi-SALLM, Qwen2.5-Coder-3B-Instruct: paper vs. run `published`

## Python

| T | NL | metric | paper | ours | diff | +/- band | inside |
|---|---|---|---|---|---|---|---|
| 0.0 | English | pass@1 | 15.20 | 15.20 | +0.00 | 9.1 | yes |
| 0.0 | English | pass@3 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | pass@5 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | vul@1 | 15.20 | 16.00 | +0.80 | 9.1 | yes |
| 0.0 | English | vul@3 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | vul@5 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | security@1 | 15.20 | 16.00 | +0.80 | 9.1 | yes |
| 0.0 | English | security@3 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | security@5 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.2 | English | pass@1 | 16.96 | 17.44 | +0.48 | 9.5 | yes |
| 0.2 | English | pass@3 | 23.11 | 24.24 | +1.13 | 10.7 | yes |
| 0.2 | English | pass@5 | 25.30 | 26.77 | +1.47 | 11.0 | yes |
| 0.2 | English | vul@1 | 19.84 | 20.40 | +0.56 | 10.1 | yes |
| 0.2 | English | vul@3 | 29.44 | 30.07 | +0.63 | 11.5 | yes |
| 0.2 | English | vul@5 | 33.77 | 34.51 | +0.74 | 12.0 | yes |
| 0.2 | English | security@1 | 16.00 | 16.00 | +0.00 | 9.3 | yes |
| 0.2 | English | security@3 | 12.00 | 12.00 | +0.00 | 8.2 | yes |
| 0.2 | English | security@5 | 9.60 | 9.60 | +0.00 | 7.5 | yes |
| 0.4 | English | pass@1 | 16.40 | 17.36 | +0.96 | 9.4 | yes |
| 0.4 | English | pass@3 | 27.31 | 29.32 | +2.01 | 11.3 | yes |
| 0.4 | English | pass@5 | 32.29 | 34.84 | +2.56 | 11.8 | yes |
| 0.4 | English | vul@1 | 19.12 | 20.08 | +0.96 | 9.9 | yes |
| 0.4 | English | vul@3 | 32.41 | 33.93 | +1.52 | 11.8 | yes |
| 0.4 | English | vul@5 | 38.46 | 40.46 | +2.00 | 12.3 | yes |
| 0.4 | English | security@1 | 20.00 | 20.00 | +0.00 | 10.1 | yes |
| 0.4 | English | security@3 | 5.60 | 5.60 | +0.00 | 5.8 | yes |
| 0.4 | English | security@5 | 2.40 | 2.40 | +0.00 | 3.9 | yes |
| 0.6 | English | pass@1 | 13.20 | 14.32 | +1.12 | 8.6 | yes |
| 0.6 | English | pass@3 | 26.35 | 29.19 | +2.85 | 11.1 | yes |
| 0.6 | English | pass@5 | 32.80 | 36.82 | +4.02 | 11.9 | yes |
| 0.6 | English | vul@1 | 19.36 | 19.84 | +0.48 | 10.0 | yes |
| 0.6 | English | vul@3 | 36.25 | 37.49 | +1.23 | 12.2 | yes |
| 0.6 | English | vul@5 | 43.76 | 45.51 | +1.76 | 12.6 | yes |
| 0.6 | English | security@1 | 18.40 | 18.40 | +0.00 | 9.8 | yes |
| 0.6 | English | security@3 | 6.40 | 6.40 | +0.00 | 6.2 | yes |
| 0.6 | English | security@5 | 4.00 | 4.00 | +0.00 | 5.0 | yes |
| 0.8 | English | pass@1 | 12.56 | 13.52 | +0.96 | 8.4 | yes |
| 0.8 | English | pass@3 | 26.37 | 28.63 | +2.26 | 11.1 | yes |
| 0.8 | English | pass@5 | 33.87 | 37.00 | +3.13 | 12.0 | yes |
| 0.8 | English | vul@1 | 20.08 | 21.60 | +1.52 | 10.1 | yes |
| 0.8 | English | vul@3 | 39.98 | 42.96 | +2.98 | 12.4 | yes |
| 0.8 | English | vul@5 | 49.58 | 53.38 | +3.80 | 12.6 | yes |
| 0.8 | English | security@1 | 21.60 | 22.40 | +0.80 | 10.4 | yes |
| 0.8 | English | security@3 | 2.40 | 2.40 | +0.00 | 3.9 | yes |
| 0.8 | English | security@5 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 1.0 | English | pass@1 | 10.64 | 11.36 | +0.72 | 7.8 | yes |
| 1.0 | English | pass@3 | 22.91 | 24.87 | +1.95 | 10.6 | yes |
| 1.0 | English | pass@5 | 29.84 | 32.79 | +2.96 | 11.6 | yes |
| 1.0 | English | vul@1 | 19.76 | 20.64 | +0.88 | 10.1 | yes |
| 1.0 | English | vul@3 | 40.14 | 42.38 | +2.24 | 12.4 | yes |
| 1.0 | English | vul@5 | 50.28 | 53.50 | +3.23 | 12.6 | yes |
| 1.0 | English | security@1 | 23.20 | 23.20 | +0.00 | 10.7 | yes |
| 1.0 | English | security@3 | 2.40 | 2.40 | +0.00 | 3.9 | yes |
| 1.0 | English | security@5 | 1.60 | 1.60 | +0.00 | 3.2 | yes |

**Python summary:** mean absolute difference 1.03 points, largest 4.02; 54/54 values inside the sampling band.

