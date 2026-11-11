#!/usr/bin/env bash
# Multi-SALLM replication driver (Qwen2.5-Coder-3B-Instruct).
#
#   run.sh refcheck        no GPU. Run the dataset's own reference solutions through the
#                          whole evaluation pipeline (environment check).
#   run.sh verify-filter   no GPU. Does our repair driver reproduce the authors'
#                          published repaired outputs from their raw outputs?
#   run.sh published       no GPU. Re-test the authors' published Qwen generations and
#                          compare with the paper's numbers (evaluation fidelity).
#   run.sh generate        GPU. Fresh generations from a local vLLM server + repair.
#   run.sh evaluate        no GPU. Test the fresh generations, compute the metrics.
#   run.sh compare [run]   Print paper-vs-ours tables for a run (default: fresh).
#
# Scope (environment variables):
#   PLS="python"           languages: any of "python cpp java"      (default: python)
#   LANGS="English"        natural languages, comma separated, or "all" for the 23
#   TEMPS="0.0,0.2,0.4,0.6,0.8,1.0"
#   SALLM_WORKERS=4        parallel test processes (default: number of cores)
#   RUN=fresh              name of the fresh run (lets you keep several side by side)
set -euo pipefail
source "$(dirname "$0")/../common/env.sh"
PLS="${PLS:-python}"
LANGS="${LANGS:-English}"
TEMPS="${TEMPS:-0.0,0.2,0.4,0.6,0.8,1.0}"
RUN="${RUN:-fresh}"
export SALLM_WORKERS="${SALLM_WORKERS:-$(nproc)}"

S="$WORK/SALLM"
PY="$VENVS/sallm-tools/bin/python"
export SALLM_ROOT="$S"
export SALLM_TEST_PY="$VENVS/sallm-tests/bin/python"
if [ -f "$WORK/sallm_java.env" ]; then source "$WORK/sallm_java.env"; fi
export PATH="$WORK/bin:$VENVS/sallm-tools/bin:$PATH"
[ -x "$WORK/bin/apptainer" ] || { echo "run multisallm/setup.sh first"; exit 1; }

# The authors' scripts read and write fixed folders inside the clone. Each run gets its
# own copy of those folders under $WORK/runs/<name>/, linked into the clone on demand.
MUTABLE=(Generation/Output Generation/Filtered_Output Evaluation/TestResults Evaluation/Result
  Evaluation/TestModelsResults_Python Evaluation/TestModelsResults_GitHub_Python
  Evaluation/TestModelsResults_Java Evaluation/TestModelsResults_GitHub_Java
  Evaluation/TestModelsResults_Cpp Evaluation/TestModelsResults_GitHub_Cpp)
use_run() {
  local name="$1" d
  RUN_DIR="$WORK/runs/multisallm/$name"
  for d in "${MUTABLE[@]}"; do
    mkdir -p "$RUN_DIR/$d"
    if [ -L "$S/$d" ]; then rm "$S/$d"; elif [ -e "$S/$d" ]; then echo "unexpected real folder $S/$d"; exit 1; fi
    ln -s "$RUN_DIR/$d" "$S/$d"
  done
  log "run '$name' -> $RUN_DIR"
}

lang_arg() { case "$1" in python) echo Python;; java) echo Java;; cpp) echo cpp;; esac; }

evaluate() {  # $1 = model tag in the file names
  local tag="$1" pl hold="$RUN_DIR/.github_hold"
  cd "$S/Evaluation"
  for pl in $PLS; do
    local L; L="$(lang_arg "$pl")"
    # `--no-github` does not exclude the GitHub-derived files, it only changes where
    # results are stored; the authors therefore run both variants. Hide the GitHub
    # files during the standard pass so they are not tested twice.
    mkdir -p "$hold"
    find -L "$S/Generation/Filtered_Output" -maxdepth 1 -name 'github-dataset_*' -exec mv {} "$hold/" \;
    log "tests: $L, standard prompts (workers=$SALLM_WORKERS)"
    "$PY" run_tests_native.py --model "$tag" --lang "$L" --no-github
    find "$hold" -maxdepth 1 -name 'github-dataset_*' -exec mv {} "$RUN_DIR/Generation/Filtered_Output/" \;
    log "tests: $L, GitHub/CVE-derived prompts"
    "$PY" run_tests_native.py --model "$tag" --lang "$L" --github
  done
  log "annotate samples with test outcomes, then pass@k / vul@k / security@k (authors' scripts)"
  "$PY" run_test_evaluation.py
  "$PY" run_pass_at_k.py | tail -n 12
  rm -rf "$S"/Evaluation/temp_*
}

compare() {  # $1 = run name
  "$PY" "$REPL/multisallm/compare.py" --run-dir "$WORK/runs/multisallm/$1" \
    --targets "$REPL/multisallm/paper_targets" --name "$1" \
    --out "$WORK/results/multisallm_$1.md"
}

published_files() {  # names of the authors' published Filtered_Output files for $PLS / $TEMPS
  local pl t
  for pl in $PLS; do
    for t in ${TEMPS//,/ }; do
      case "$pl" in
        python) echo "dataset_nl_prompt_best_qwen2.5_$t.jsonl github-dataset_nl_prompt_best_qwen2.5_$t.jsonl";;
        java)   echo "dataset_java_nl_prompt_best_qwen2.5_$t.jsonl github-dataset_java_nl_prompt_best_qwen2.5_$t.jsonl";;
        cpp)    echo "dataset_cpp_nl_prompt_best_Qwen2.5_$t.jsonl github-dataset_cpp_nl_prompt_best_Qwen2.5_$t.jsonl";;
      esac
    done
  done
}
fetch_published() {
  PUB="$WORK/published/Filtered_Output"
  mkdir -p "$PUB"
  local f
  for f in $(published_files); do
    LFS_DEST_DIR="$PUB" "$REPL/multisallm/fetch_lfs.sh" "$S" "Generation/Filtered_Output/$f"
  done
}

case "${1:-}" in
  refcheck)
    use_run reference
    "$PY" "$REPL/multisallm/make_inputs.py" reference --sallm "$S" \
      --out "$RUN_DIR/Generation/Filtered_Output" --pls "${PLS// /,}"
    evaluate reference
    compare reference
    ;;
  verify-filter)
    fetch_published
    "$PY" "$REPL/multisallm/filter_native.py" verify --sallm "$S" --published "$PUB" --langs "$LANGS" --show
    ;;
  published)
    fetch_published
    use_run published
    "$PY" "$REPL/multisallm/make_inputs.py" published --src "$PUB" \
      --out "$RUN_DIR/Generation/Filtered_Output" --langs "$LANGS"
    evaluate qwen2.5
    compare published
    ;;
  generate)
    use_run "$RUN"
    for pl in $PLS; do
      case "$pl" in python) pre="";; java) pre="_java";; cpp) pre="_cpp";; esac
      for ds in dataset github-dataset; do
        "$PY" "$REPL/multisallm/generate.py" "$S/ProcessedFiles/${ds}${pre}_nl_prompt_best.jsonl" \
          --out-dir "$S/Generation/Output" --langs "$LANGS" --temps "$TEMPS" ${GEN_ARGS:-}
      done
    done
    log "rule-based repair (authors' filter_code.py)"
    "$PY" "$REPL/multisallm/filter_native.py" filter --sallm "$S" --pattern qwen2.5
    ;;
  evaluate)
    use_run "$RUN"
    evaluate qwen2.5
    compare "$RUN"
    ;;
  compare)
    compare "${2:-$RUN}"
    ;;
  *)
    sed -n '2,20p' "$0"; exit 1;;
esac
