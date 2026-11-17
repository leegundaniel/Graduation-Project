# Multi-SALLM, Qwen2.5-Coder-3B-Instruct: paper vs. run `reference`

## Python: reference (insecure) solutions through the pipeline

| prompts tested | functional test passes | security test fails |
|---|---|---|
| English | 86.4% | 10.4% |

Expected: the functional column close to 100%. The second column is the share of *known-vulnerable* solutions whose security test fails; it tells you which outcome the released metric code counts (see README).

