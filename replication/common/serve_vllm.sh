#!/usr/bin/env bash
# Start (or stop) a local OpenAI-compatible model server with vLLM.
#
#   serve_vllm.sh start llama     Llama 3.1 8B Instruct, split over all GPUs (needs 2x T4)
#   serve_vllm.sh start qwen      Qwen2.5-Coder-3B-Instruct on one GPU
#   serve_vllm.sh stop
#   serve_vllm.sh status
#
# Both papers queried their models through an OpenAI-style API, so both pipelines talk
# to this server exactly as they would to a hosted endpoint.
#
# Settings worth knowing:
#   --dtype half        T4 GPUs have no bfloat16; float16 is the full-precision choice there.
#   sampling defaults   vLLM takes unspecified sampling parameters (top_k, repetition
#                       penalty, ...) from the model's own generation_config.json, the
#                       same defaults Hugging Face `generate` uses. Temperature, top_p,
#                       n and max tokens are always set explicitly by the pipelines.
#   VLLM_EXTRA_ARGS     appended to the command line if you need anything else.
set -euo pipefail
source "$(dirname "$0")/env.sh"
PIDFILE="$WORK/vllm.pid"
LOGFILE="$WORK/vllm.log"

stop() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill "$(cat "$PIDFILE")" && sleep 5
    kill -9 "$(cat "$PIDFILE")" 2>/dev/null || true
    log "vLLM stopped"
  fi
  rm -f "$PIDFILE"
}

case "${1:-}" in
  stop) stop; exit 0;;
  status)
    curl -fsS "http://localhost:$VLLM_PORT/v1/models" && echo || { echo "not running"; exit 1; }
    exit 0;;
  start) ;;
  *) sed -n '2,8p' "$0"; exit 1;;
esac

NGPU="$(nvidia-smi -L 2>/dev/null | wc -l)"
if [ "$NGPU" -lt 1 ]; then echo "No GPU visible. On Kaggle: Settings -> Accelerator -> GPU T4 x2."; exit 1; fi

case "${2:-}" in
  llama) MODEL="$LLAMA_MODEL"; TP="${TP:-$NGPU}";;
  qwen)  MODEL="$QWEN_MODEL";  TP="${TP:-1}";;
  *) echo "usage: serve_vllm.sh start llama|qwen"; exit 1;;
esac

stop
ensure_uv
if [ ! -x "$VENVS/vllm/bin/vllm" ]; then
  log "installing vLLM into its own environment (several minutes, ~8 GB)"
  uv venv -q --python 3.11 "$VENVS/vllm"
  uv pip install -q --python "$VENVS/vllm/bin/python" "vllm${VLLM_VERSION:+==$VLLM_VERSION}"
fi

if [ "$TP" = 1 ]; then export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"; fi
log "starting vLLM: $MODEL on $TP GPU(s), log: $LOGFILE"
# shellcheck disable=SC2086
nohup "$VENVS/vllm/bin/vllm" serve "$MODEL" \
  --port "$VLLM_PORT" --served-model-name "$MODEL" \
  --dtype half --tensor-parallel-size "$TP" \
  --max-model-len "${MAX_MODEL_LEN:-8192}" --gpu-memory-utilization "${GPU_MEM:-0.92}" \
  ${VLLM_EXTRA_ARGS:-} >"$LOGFILE" 2>&1 &
echo $! > "$PIDFILE"

for i in $(seq 1 180); do   # model download + load can take a while
  if curl -fsS "http://localhost:$VLLM_PORT/v1/models" >/dev/null 2>&1; then
    log "vLLM is up: $MODEL"
    grep -i -m3 'generation config\|default sampling' "$LOGFILE" || true
    exit 0
  fi
  if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "vLLM exited. Last log lines:"; tail -n 40 "$LOGFILE"; exit 1
  fi
  sleep 10
done
echo "vLLM did not come up within 30 minutes. See $LOGFILE"; exit 1
