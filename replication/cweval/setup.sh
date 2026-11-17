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
# The JS tasks' packages (jsdom, argon2, sqlite3) need Node >= 18; Ubuntu's apt Node is
# older, so use the official Node 22 binaries unless a recent Node is already present.
NODE_DIR="$WORK/node-toolchain"
node_major() { node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/'; }
if [ -x "$NODE_DIR/bin/node" ]; then export PATH="$NODE_DIR/bin:$PATH"; fi
if [ "$(node_major || echo 0)" -lt 18 ] 2>/dev/null || ! command -v node >/dev/null 2>&1; then
  mkdir -p "$NODE_DIR"
  curl -fsSL https://nodejs.org/dist/v22.11.0/node-v22.11.0-linux-x64.tar.xz \
    | tar -xJ -C "$NODE_DIR" --strip-components=1
  export PATH="$NODE_DIR/bin:$PATH"
fi
echo "   node $(node -v)"
NODE_PREFIX="$WORK/node_global"
mkdir -p "$NODE_PREFIX"
# Two packages are pinned to the versions of the authors' Docker image (late 2024):
#   node-rsa 2.x (2025) changed its API, so `new NodeRSA(...)` throws "not a constructor";
#   sqlite3 6.x prebuilt binaries do not load on Kaggle's image; 5.1.7 does.
# Everything else is installed as in the upstream Dockerfile (latest).
if [ ! -f "$NODE_PREFIX/.pinned-v1" ]; then
  npm install -g --silent --prefix "$NODE_PREFIX" \
    escape-html node-rsa@1.1.1 argon2 escape-string-regexp lodash js-yaml jsonwebtoken jsdom xpath sqlite3@5.1.7
  touch "$NODE_PREFIX/.pinned-v1"
fi
NODE_PATH="$NODE_PREFIX/lib/node_modules" node -e \
  "new (require('node-rsa'))({b:512}); require('sqlite3'); console.log('   node-rsa and sqlite3 load')"

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
export PATH="$NODE_DIR/bin:$GO_DIR/go/bin:/usr/local/go/bin:\$HOME/go/bin:\$PATH"
ENV

log "6/6 sanity check: compile and test all reference solutions (the authors' own check)"
source "$WORK/cweval.env"
cd "$CW"
MARK="$WORK/.cweval_sanity_passed_$CWEVAL_COMMIT"
if [ -f "$MARK" ] && [ -z "${FORCE_SANITY:-}" ]; then
  log "sanity check already passed in this environment ($(cat "$MARK")); FORCE_SANITY=1 re-runs it"
  exit 0
fi
python cweval/commons.py compile_all_in --path benchmark/ --num_proc "$NPROC" >"$WORK/cweval_compile.log" 2>&1
set +e
# One worker on purpose: with pytest-xdist the workers sometimes collect different test
# lists ("Different tests were collected between gw0 and gw1") and nothing runs at all.
pytest benchmark/ -q -p no:cacheprovider 2>&1 | tee "$WORK/cweval_sanity.log" | tail -15
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" -eq 0 ]; then tail -n 1 "$WORK/cweval_sanity.log" > "$MARK"; fi
if [ "$rc" -ne 0 ]; then
  log "SANITY CHECK FAILED (exit $rc). Do not trust evaluation numbers until this passes."
  log "See $WORK/cweval_sanity.log and $WORK/cweval_compile.log"
  exit "$rc"
fi
log "CWEval environment ready. Full sanity log: $WORK/cweval_sanity.log"
