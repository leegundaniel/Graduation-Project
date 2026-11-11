#!/usr/bin/env bash
# Shared settings for both replications. Source this file; do not execute it.
#
#   WORK  - where upstream repos, virtualenvs and results live.
#           On Kaggle this defaults to /kaggle/working/replication_work
#           (persisted when you "Save Version").
#   REPL  - this replication/ directory.

REPL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${WORK:-}" ]; then
  if [ -d /kaggle/working ]; then
    WORK=/kaggle/working/replication_work
  else
    WORK="$REPL/../work"
  fi
fi
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"
export REPL WORK

# Pinned upstream revisions (the public replication packages of the two papers).
export CWEVAL_REPO=https://github.com/Co1lin/CWEval.git
export CWEVAL_COMMIT=e9a2a124c8c53679b6d8d27adfd2f6c40e7576d7
export SALLM_REPO=https://github.com/s2e-lab/SALLM.git
export SALLM_BRANCH=multi-sallm
export SALLM_COMMIT=b9fe2b0ebc58b11af8355f7852858be0b58c68c2

# Models. Override with e.g. LLAMA_MODEL=unsloth/Meta-Llama-3.1-8B-Instruct (see README).
export LLAMA_MODEL="${LLAMA_MODEL:-meta-llama/Meta-Llama-3.1-8B-Instruct}"
export QWEN_MODEL="${QWEN_MODEL:-Qwen/Qwen2.5-Coder-3B-Instruct}"

export VLLM_PORT="${VLLM_PORT:-8000}"
export VENVS="$WORK/venvs"
export PATH="$HOME/.local/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"

log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi
export SUDO

ensure_uv() {
  if command -v uv >/dev/null 2>&1; then return; fi
  log "installing uv (Python environment manager)"
  python3 -m pip install -q uv
}
