#!/usr/bin/env bash
# Multi-SALLM environment for Kaggle or any Ubuntu machine, without Docker/Apptainer.
#
#   PLS="python"            (default) Python only: fastest, start here
#   PLS="python cpp"        adds the C++ GoogleTest toolchain
#   PLS="python cpp java"   adds JDK 8 + Maven and a warmed-up offline Maven cache
#
# What it prepares:
#   - the authors' replication package at a pinned commit (without the multi-GB LFS payload)
#   - the multilingual prompt files (fetched from Git LFS one by one)
#   - a Python 3.10 environment with the exact pinned requirements of the authors'
#     per-prompt Docker images (they are all python:3.10-slim + the same 5 packages)
#   - a native stand-in for `apptainer` so the authors' own test runner runs unmodified
set -euo pipefail
source "$(dirname "$0")/../common/env.sh"
PLS="${PLS:-python}"
S="$WORK/SALLM"

log "1/7 clone Multi-SALLM @ ${SALLM_COMMIT:0:10} (LFS files stay as pointers)"
export GIT_LFS_SKIP_SMUDGE=1
if [ ! -d "$S/.git" ]; then
  git init -q "$S"
  git -C "$S" remote add origin "$SALLM_REPO"
  git -C "$S" fetch -q --depth 1 origin "$SALLM_COMMIT"
  git -C "$S" checkout -q FETCH_HEAD
fi

log "2/7 fetch the prompt files from Git LFS"
"$REPL/multisallm/fetch_lfs.sh" "$S" \
  ProcessedFiles/dataset_nl_prompt_best.jsonl \
  ProcessedFiles/github-dataset_nl_prompt_best.jsonl \
  ProcessedFiles/dataset_java_nl_prompt_best.jsonl \
  ProcessedFiles/github-dataset_java_nl_prompt_best.jsonl \
  ProcessedFiles/dataset_cpp_nl_prompt_best.jsonl \
  ProcessedFiles/github-dataset_cpp_nl_prompt_best.jsonl

log "3/7 Python environments"
ensure_uv
if [ ! -d "$VENVS/sallm-tools" ]; then uv venv -q --python 3.10 "$VENVS/sallm-tools"; fi
uv pip install -q --python "$VENVS/sallm-tools/bin/python" tqdm pandas numpy openai
# Environment the generated code is tested in = the authors' Docker image contents.
if [ ! -d "$VENVS/sallm-tests" ]; then uv venv -q --python 3.10 "$VENVS/sallm-tests"; fi
uv pip install -q --python "$VENVS/sallm-tests/bin/python" \
  requests==2.31.0 pycryptodome==3.19.0 cryptography==41.0.3 Flask==2.3.3 Flask-SQLAlchemy==3.0.5 \
  pyyaml unittest-xml-reporting

log "4/7 keep the authors' published outputs apart from ours"
# Their Output/ and Filtered_Output/ hold LFS pointer stubs for all four models; the
# evaluation scripts would try to parse them. Park them; run.sh links per-run folders in.
for d in Generation/Output Generation/Filtered_Output Evaluation/Result; do
  if [ -d "$S/$d" ] && [ ! -L "$S/$d" ]; then mv "$S/$d" "$S/${d}_published"; fi
done

log "5/7 native stand-in for apptainer + runner copy with a configurable worker count"
mkdir -p "$WORK/bin"
install -m 0755 "$REPL/multisallm/tools/apptainer" "$WORK/bin/apptainer"
# The only change to the authors' runner: MAX_WORKERS (hard-coded 16 for their cluster)
# becomes configurable, because Kaggle has 4 cores and oversubscription causes timeouts.
sed 's/^MAX_WORKERS = 16$/MAX_WORKERS = int(os.environ.get("SALLM_WORKERS", "16"))/' \
  "$S/Evaluation/run_tests_singularity.py" > "$S/Evaluation/run_tests_native.py"
grep -q 'SALLM_WORKERS' "$S/Evaluation/run_tests_native.py" || {
  echo "could not patch MAX_WORKERS in run_tests_singularity.py (upstream changed?)"; exit 1; }

log "6/7 placeholder image files (the runner only checks that an image exists per prompt)"
"$VENVS/sallm-tools/bin/python" - "$S" <<'PY'
import json, os, sys
root = sys.argv[1]
sif = os.path.join(root, "Evaluation", "sif_images")
os.makedirs(sif, exist_ok=True)
n = 0
for name in ["dataset", "github-dataset", "dataset_java", "github-dataset_java"]:
    path = os.path.join(root, "ProcessedFiles", f"{name}_nl_prompt_best.jsonl")
    is_python = "java" not in name
    with open(path, encoding="utf-8") as f:
        for line in f:
            d = json.loads(line)
            technique, source = d.get("technique", "Assertion"), d.get("source", "Author")
            item_id = os.path.splitext(d["id"])[0]
            prefix = f"{technique}_{source}_"
            if item_id.startswith(prefix):
                item_id = item_id[len(prefix):]
            if is_python:
                fn = f"sallm-py-{item_id}.sif"
            elif technique.lower() != "github":
                fn = f"sallm-java-{technique}-{item_id}.sif"
            else:
                fn = f"sallm-java-{item_id}.sif"
            open(os.path.join(sif, fn.lower()), "a").close()
            n += 1
print(f"   {n} placeholders in {sif}")
PY

log "7/7 language toolchains: $PLS"
export DEBIAN_FRONTEND=noninteractive
if [[ " $PLS " == *" cpp "* ]]; then
  B="$S/DatasetCPP/build"
  if [ ! -f "$B/lib/libgtest_main.a" ]; then
    $SUDO apt-get install -y -qq build-essential cmake unzip >/dev/null
    GT=03597a01ee50ed33e9dfd640b249b4be3799d395   # the commit pinned in DatasetCPP/CMakeLists.txt
    mkdir -p "$B/_deps" "$B/lib"
    curl -fsSL "https://github.com/google/googletest/archive/$GT.zip" -o "$B/_deps/gtest.zip"
    unzip -q -o "$B/_deps/gtest.zip" -d "$B/_deps" && rm "$B/_deps/gtest.zip"
    rm -rf "$B/_deps/googletest-src" && mv "$B/_deps/googletest-$GT" "$B/_deps/googletest-src"
    cmake -S "$B/_deps/googletest-src" -B "$B/_deps/googletest-build" -DCMAKE_CXX_STANDARD=17 >/dev/null
    cmake --build "$B/_deps/googletest-build" -j "$(nproc)" >/dev/null
    cp "$B/_deps/googletest-build/lib/libgtest.a" "$B/_deps/googletest-build/lib/libgtest_main.a" "$B/lib/"
  fi
  echo "   GoogleTest ready in $B/lib"
fi
if [[ " $PLS " == *" java "* ]]; then
  $SUDO apt-get install -y -qq openjdk-8-jdk-headless maven >/dev/null
  JAVA8="$(dirname "$(dirname "$(update-alternatives --list javac | grep -m1 'java-8')")")"
  echo "export SALLM_JAVA_HOME=$JAVA8" > "$WORK/sallm_java.env"
  REPO="$S/DatasetJava/.m2_cache/repository"
  if [ ! -d "$REPO/org/junit" ]; then
    # Warm the offline Maven cache the same way the image build does (dependency:go-offline),
    # then run one real `mvn test` per pom so the surefire/JUnit provider jars are cached too.
    for proj in DatasetJava GitHubDatasetJava; do
      tmp="$(mktemp -d)"
      cp "$S/$proj/pom.xml" "$tmp/"
      src="$(find "$S/$proj/src/main/java" -name '*_cwe*.java' | sort | head -1)"
      rel="${src#"$S/$proj/"}"
      tst="$S/$proj/$(dirname "${rel/src\/main/src\/test}")/Test$(basename "$src")"
      mkdir -p "$tmp/$(dirname "$rel")" "$tmp/$(dirname "${tst#"$S/$proj/"}")"
      cp "$src" "$tmp/$rel"; cp "$tst" "$tmp/${tst#"$S/$proj/"}"
      (cd "$tmp" && JAVA_HOME="$JAVA8" mvn -B -q dependency:go-offline "-Dmaven.repo.local=$REPO" || true)
      (cd "$tmp" && JAVA_HOME="$JAVA8" mvn -B -q test "-Dmaven.repo.local=$REPO" || true)
      rm -rf "$tmp"
    done
  fi
  echo "   JDK 8 at $JAVA8, Maven cache at $REPO"
fi

log "Multi-SALLM environment ready. Next: multisallm/run.sh refcheck"
