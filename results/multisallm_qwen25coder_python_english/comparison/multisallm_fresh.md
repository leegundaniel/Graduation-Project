# Multi-SALLM, Qwen2.5-Coder-3B-Instruct: paper vs. run `fresh`

## Python

| T | NL | metric | paper | ours | diff | +/- band | inside |
|---|---|---|---|---|---|---|---|
| 0.0 | English | pass@1 | 15.20 | 18.40 | +3.20 | 9.1 | yes |
| 0.0 | English | pass@3 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | pass@5 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | vul@1 | 15.20 | 17.60 | +2.40 | 9.1 | yes |
| 0.0 | English | vul@3 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | vul@5 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | security@1 | 15.20 | 17.60 | +2.40 | 9.1 | yes |
| 0.0 | English | security@3 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.0 | English | security@5 | 0.00 | 0.00 | +0.00 | 0.0 | yes |
| 0.2 | English | pass@1 | 16.96 | 18.48 | +1.52 | 9.5 | yes |
| 0.2 | English | pass@3 | 23.11 | 25.69 | +2.59 | 10.7 | yes |
| 0.2 | English | pass@5 | 25.30 | 29.18 | +3.87 | 11.0 | yes |
| 0.2 | English | vul@1 | 19.84 | 19.36 | -0.48 | 10.1 | yes |
| 0.2 | English | vul@3 | 29.44 | 28.26 | -1.18 | 11.5 | yes |
| 0.2 | English | vul@5 | 33.77 | 31.69 | -2.08 | 12.0 | yes |
| 0.2 | English | security@1 | 16.00 | 17.60 | +1.60 | 9.3 | yes |
| 0.2 | English | security@3 | 12.00 | 12.00 | +0.00 | 8.2 | yes |
| 0.2 | English | security@5 | 9.60 | 9.60 | +0.00 | 7.5 | yes |
| 0.4 | English | pass@1 | 16.40 | 18.64 | +2.24 | 9.4 | yes |
| 0.4 | English | pass@3 | 27.31 | 30.38 | +3.07 | 11.3 | yes |
| 0.4 | English | pass@5 | 32.29 | 35.03 | +2.74 | 11.8 | yes |
| 0.4 | English | vul@1 | 19.12 | 20.00 | +0.88 | 9.9 | yes |
| 0.4 | English | vul@3 | 32.41 | 32.99 | +0.57 | 11.8 | yes |
| 0.4 | English | vul@5 | 38.46 | 39.33 | +0.87 | 12.3 | yes |
| 0.4 | English | security@1 | 20.00 | 18.40 | -1.60 | 10.1 | yes |
| 0.4 | English | security@3 | 5.60 | 8.80 | +3.20 | 5.8 | yes |
| 0.4 | English | security@5 | 2.40 | 6.40 | +4.00 | 3.9 | NO |
| 0.6 | English | pass@1 | 13.20 | 14.80 | +1.60 | 8.6 | yes |
| 0.6 | English | pass@3 | 26.35 | 29.06 | +2.71 | 11.1 | yes |
| 0.6 | English | pass@5 | 32.80 | 35.91 | +3.11 | 11.9 | yes |
| 0.6 | English | vul@1 | 19.36 | 19.92 | +0.56 | 10.0 | yes |
| 0.6 | English | vul@3 | 36.25 | 37.11 | +0.86 | 12.2 | yes |
| 0.6 | English | vul@5 | 43.76 | 45.70 | +1.95 | 12.6 | yes |
| 0.6 | English | security@1 | 18.40 | 17.60 | -0.80 | 9.8 | yes |
| 0.6 | English | security@3 | 6.40 | 4.80 | -1.60 | 6.2 | yes |
| 0.6 | English | security@5 | 4.00 | 2.40 | -1.60 | 5.0 | yes |
| 0.8 | English | pass@1 | 12.56 | 14.32 | +1.76 | 8.4 | yes |
| 0.8 | English | pass@3 | 26.37 | 29.65 | +3.28 | 11.1 | yes |
| 0.8 | English | pass@5 | 33.87 | 38.56 | +4.69 | 12.0 | yes |
| 0.8 | English | vul@1 | 20.08 | 19.76 | -0.32 | 10.1 | yes |
| 0.8 | English | vul@3 | 39.98 | 40.10 | +0.12 | 12.4 | yes |
| 0.8 | English | vul@5 | 49.58 | 50.59 | +1.01 | 12.6 | yes |
| 0.8 | English | security@1 | 21.60 | 16.80 | -4.80 | 10.4 | yes |
| 0.8 | English | security@3 | 2.40 | 6.40 | +4.00 | 3.9 | NO |
| 0.8 | English | security@5 | 0.00 | 1.60 | +1.60 | 0.0 | NO |
| 1.0 | English | pass@1 | 10.64 | 10.56 | -0.08 | 7.8 | yes |
| 1.0 | English | pass@3 | 22.91 | 24.33 | +1.42 | 10.6 | yes |
| 1.0 | English | pass@5 | 29.84 | 32.87 | +3.03 | 11.6 | yes |
| 1.0 | English | vul@1 | 19.76 | 19.68 | -0.08 | 10.1 | yes |
| 1.0 | English | vul@3 | 40.14 | 41.69 | +1.55 | 12.4 | yes |
| 1.0 | English | vul@5 | 50.28 | 52.76 | +2.48 | 12.6 | yes |
| 1.0 | English | security@1 | 23.20 | 20.00 | -3.20 | 10.7 | yes |
| 1.0 | English | security@3 | 2.40 | 4.00 | +1.60 | 3.9 | yes |
| 1.0 | English | security@5 | 1.60 | 0.00 | -1.60 | 3.2 | yes |

**Python summary:** mean absolute difference 1.70 points, largest 4.80; 51/54 values inside the sampling band.

