#!/usr/bin/env bash
# Native (no-Docker) equivalent of CWEval's Dockerfile, for Kaggle or any Ubuntu machine.
#
# Kaggle notebooks cannot run Docker, so this rebuilds the image's toolchain directly:
# a Python 3.10 environment, the C/C++ libraries the tasks link against, Node with the
# npm packages the JS tasks import, and Go 1.23 with the benchmark's modules.
#
# It ends with the paper authors' own sanity check: every reference solution in the
# benchmark must pass its test oracle. If that check is green, the evaluation side of
# the replication behaves the same as the authors' Docker image.
set -euo pipefail
source "$(dirname "$0")/../common/env.sh"
NPROC="${NPROC:-$(nproc)}"
CW="$WORK/CWEval"

log "1/6 clone CWEval @ ${CWEVAL_COMMIT:0:10}"
if [ ! -d "$CW/.git" ]; then git clone "$CWEVAL_REPO" "$CW"; fi
git -C "$CW" checkout -q "$CWEVAL_COMMIT" 2>/dev/null || {
  git -C "$CW" fetch -q origin && git -C "$CW" checkout -q "$CWEVAL_COMMIT"
}

log "2/6 system libraries (C/C++ tasks link against these)"
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq build-essential pkg-config curl wget git \
  libjwt-dev libarchive-dev libxml2-dev libsqlite3-dev libssl-dev zlib1g-dev liblzma-dev >/dev/null

log "3/6 Python 3.10 environment"
ensure_uv
if [ ! -d "$VENVS/cweval" ]; then uv venv -q --python 3.10 "$VENVS/cweval"; fi
# core.txt holds the benchmark's runtime dependencies. From ai.txt only the
# OpenAI-compatible client path (litellm + openai) is needed for a local vLLM server.
uv pip install -q --python "$VENVS/cweval/bin/python" -r "$CW/requirements/core.txt" litellm openai

log "4/6 Node.js + the npm packages the JS tasks import"
if ! command -v node >/dev/null 2>&1; then
  $SUDO apt-get install -y -qq nodejs npm >/dev/null
fi
NODE_PREFIX="$WORK/node_global"
mkdir -p "$NODE_PREFIX"
if [ ! -d "$NODE_PREFIX/lib/node_modules/sqlite3" ]; then
  npm install -g --silent --prefix "$NODE_PREFIX" \
    escape-html node-rsa argon2 escape-string-regexp lodash js-yaml jsonwebtoken jsdom xpath sqlite3
fi

log "5/6 Go toolchain + modules"
GO_DIR="$WORK/go-toolchain"
need_go=1
if command -v go >/dev/null 2>&1; then
  v="$(go env GOVERSION | sed 's/^go//')"
  if [ "$(printf '%s\n1.23.3\n' "$v" | sort -V | head -1)" = "1.23.3" ]; then need_go=0; fi
fi
if [ "$need_go" = 1 ] && [ ! -x "$GO_DIR/go/bin/go" ]; then
  mkdir -p "$GO_DIR"
  wget -q https://go.dev/dl/go1.23.3.linux-amd64.tar.gz -O "$GO_DIR/go.tgz"
  tar -C "$GO_DIR" -xzf "$GO_DIR/go.tgz" && rm "$GO_DIR/go.tgz"
fi
if [ -x "$GO_DIR/go/bin/go" ]; then export PATH="$GO_DIR/go/bin:$PATH"; fi
(cd "$CW" && go mod download)
if ! command -v goimports >/dev/null 2>&1; then go install golang.org/x/tools/cmd/goimports@latest; fi

# Environment file used by every later step (mirrors upstream .env, minus conda/nvm).
cat > "$WORK/cweval.env" <<ENV
source "$VENVS/cweval/bin/activate"
export PYTHONPATH="$CW:\${PYTHONPATH:-}"
export NODE_PATH="$NODE_PREFIX/lib/node_modules"
export PATH="$GO_DIR/go/bin:/usr/local/go/bin:\$HOME/go/bin:\$PATH"
ENV

log "6/6 sanity check: compile and test all reference solutions (the authors' own check)"
source "$WORK/cweval.env"
cd "$CW"
python cweval/commons.py compile_all_in --path benchmark/ --num_proc "$NPROC" >"$WORK/cweval_compile.log" 2>&1
set +e
pytest benchmark/ -n "$NPROC" -q -p no:cacheprovider 2>&1 | tee "$WORK/cweval_sanity.log" | tail -15
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" -ne 0 ]; then
  log "SANITY CHECK FAILED (exit $rc). Do not trust evaluation numbers until this passes."
  log "See $WORK/cweval_sanity.log and $WORK/cweval_compile.log"
  exit "$rc"
fi
log "CWEval environment ready. Full sanity log: $WORK/cweval_sanity.log"
