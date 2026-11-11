#!/usr/bin/env bash
# CWEval replication driver (Llama 3.1 8B Instruct), using the authors' own scripts.
#
#   run.sh generate   GPU. Needs `common/serve_vllm.sh start llama` running.
#   run.sh evaluate   no GPU. Compile + run the functionality and security oracles.
#   run.sh compare    Paper-vs-ours table.
#
# Settings (environment variables):
#   CONFIGS="t0.8 greedy"   which of the paper's settings to run (default: both)
#        t0.8    n=100 samples per task at temperature 0.8  -> Table I row
#        greedy  1 deterministic sample per task            -> Fig. 3 func@1*, func-sec@1*
#        t0.2 t0.4 t0.6  the other RQ1 temperatures (Fig. 3 reports the best of the four)
#   N=100                   samples per task for the sampling settings
#   GEN_PROCS=4             tasks requested in parallel (each asks for N samples at once)
#   NPROC=<cores>           parallel test workers
set -euo pipefail
source "$(dirname "$0")/../common/env.sh"
CONFIGS="${CONFIGS:-t0.8 greedy}"
N="${N:-100}"
GEN_PROCS="${GEN_PROCS:-4}"
NPROC="${NPROC:-$(nproc)}"
CW="$WORK/CWEval"
[ -f "$WORK/cweval.env" ] || { echo "run cweval/setup.sh first"; exit 1; }
source "$WORK/cweval.env"
cd "$CW"
mkdir -p "$WORK/runs/cweval" && [ -e evals ] || ln -s "$WORK/runs/cweval" evals

eval_path() { echo "evals/llama31_8b_$1"; }
settings() {  # -> "<n> <temperature>"
  case "$1" in
    greedy) echo "1 0";;
    t0.*)   echo "$N ${1#t}";;
    *) echo "unknown config $1" >&2; exit 1;;
  esac
}

case "${1:-}" in
  generate)
    export OPENAI_API_KEY="${OPENAI_API_KEY:-EMPTY}"   # the local server ignores it
    for cfg in $CONFIGS; do
      read -r n temp <<<"$(settings "$cfg")"
      ep="$(eval_path "$cfg")"
      log "generate $cfg: n=$n, temperature=$temp -> $ep"
      # The authors' script asks before reusing a folder; answering yes resumes, because it
      # skips every task whose n samples are already on disk.
      echo y | python cweval/generate.py gen --n "$n" --temperature "$temp" \
        --num_proc "$GEN_PROCS" --eval_path "$ep" \
        --model "openai/$LLAMA_MODEL" --api_base "http://localhost:$VLLM_PORT/v1" --timeout 7200
      missing=$(( 119 * n - $(find "$ep" -name '*_raw.*' | wc -l) ))
      if [ "$missing" -ne 0 ]; then
        echo "WARNING: $missing of $((119 * n)) samples are missing in $ep; re-run generate to fill them."
      fi
    done
    ;;
  evaluate)
    for cfg in $CONFIGS; do
      ep="$(eval_path "$cfg")"
      [ -d "$ep" ] || { echo "no generations in $ep, skipping"; continue; }
      log "evaluate $cfg (workers=$NPROC); log: $ep/pipeline.log"
      python cweval/evaluate.py pipeline --eval_path "$ep" --num_proc "$NPROC" --docker False \
        2>&1 | tee "$ep/pipeline.log" | tail -n 12
    done
    ;;
  compare)
    python "$REPL/cweval/compare.py" --evals "$WORK/runs/cweval" \
      --targets "$REPL/cweval/paper_targets.json" --out "$WORK/results/cweval.md"
    ;;
  *)
    sed -n '2,16p' "$0"; exit 1;;
esac
