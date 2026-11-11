#!/usr/bin/env bash
# Run every remaining stage in order, unattended, with one log file per stage.
#
#   ./run_all.sh multisallm     Multi-SALLM only (Qwen2.5-Coder)
#   ./run_all.sh cweval         CWEval only (Llama 3.1 8B; needs HF_TOKEN or LLAMA_MODEL)
#   ./run_all.sh all            both, Multi-SALLM first
#
# Start it so it survives a dropped VS Code connection:
#   nohup ./run_all.sh all > /kaggle/working/run_all.log 2>&1 &
#   tail -f /kaggle/working/run_all.log
#
# A failed stage is reported and the script moves on to the next independent part, so
# one problem does not waste the session. Every stage is resumable: just run it again.
source "$(dirname "$0")/common/env.sh"
cd "$REPL"
# Only one copy at a time: two copies share folders, the GPU and port 8000, and corrupt each other.
exec 9> "$WORK/run_all.lock"
if ! flock -n 9; then
  echo "Another run_all.sh is already running (see: pgrep -fa run_all.sh). Not starting a second one."
  exit 1
fi
LOGS="$WORK/logs"; mkdir -p "$LOGS" "$WORK/results"
SUMMARY="$WORK/results/run_all_summary.txt"; : > "$SUMMARY"

stage() {  # stage <name> <command...>   -> returns the command's exit code
  local name="$1"; shift
  log "START $name"
  local t0=$SECONDS rc
  "$@" > "$LOGS/$name.log" 2>&1; rc=$?
  local line
  if [ $rc -eq 0 ]; then line="OK    $name ($((SECONDS - t0))s)"; else line="FAIL  $name (exit $rc) -> $LOGS/$name.log"; fi
  echo "$line" | tee -a "$SUMMARY"
  if [ $rc -ne 0 ]; then echo "----- last lines of $name -----"; tail -n 25 "$LOGS/$name.log"; fi
  return $rc
}

multisallm() {
  stage ms_setup multisallm/setup.sh || return 1
  stage ms_refcheck multisallm/run.sh refcheck
  stage ms_verify_filter multisallm/run.sh verify-filter
  stage ms_published multisallm/run.sh published
  if stage ms_serve common/serve_vllm.sh start qwen; then
    stage ms_generate multisallm/run.sh generate && gen_ok=1
    stage ms_serve_stop common/serve_vllm.sh stop
    if [ "${gen_ok:-0}" = 1 ]; then stage ms_evaluate multisallm/run.sh evaluate; fi
  fi
}

cweval() {
  stage cw_setup cweval/setup.sh || return 1
  if stage cw_serve common/serve_vllm.sh start llama; then
    stage cw_generate cweval/run.sh generate && cw_ok=1
    stage cw_serve_stop common/serve_vllm.sh stop
    if [ "${cw_ok:-0}" = 1 ]; then
      stage cw_evaluate cweval/run.sh evaluate
      stage cw_compare cweval/run.sh compare
    fi
  fi
}

case "${1:-}" in
  multisallm) multisallm;;
  cweval) cweval;;
  all) multisallm; cweval;;
  *) sed -n '2,13p' "$0"; exit 1;;
esac

log "SUMMARY"
cat "$SUMMARY"
echo
echo "Comparison tables: $WORK/results/*.md"
tar czf "$WORK/../replication_results.tgz" -C "$WORK" --exclude=compiled results logs runs 2>/dev/null \
  && echo "Archive to download: $(cd "$WORK/.." && pwd)/replication_results.tgz"
