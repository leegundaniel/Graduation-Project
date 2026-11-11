#!/usr/bin/env bash
# Download single Git LFS files of the Multi-SALLM replication package.
# (A full `git lfs pull` is several GB: all four models, three languages, six
#  temperatures. We only need a handful of files.)
#
# usage: fetch_lfs.sh <sallm-clone> <path-in-repo>...
#   Files are written to their place in the clone, replacing the pointer stubs.
#   With LFS_DEST_DIR set, they are written to $LFS_DEST_DIR/<basename> instead.
set -euo pipefail
root="$1"; shift
base="https://media.githubusercontent.com/media/s2e-lab/SALLM/${SALLM_COMMIT:-multi-sallm}"
for rel in "$@"; do
  if [ -n "${LFS_DEST_DIR:-}" ]; then f="$LFS_DEST_DIR/$(basename "$rel")"; else f="$root/$rel"; fi
  if [ -s "$f" ] && ! head -c 60 "$f" | grep -q 'git-lfs.github.com'; then
    continue   # already the real file
  fi
  mkdir -p "$(dirname "$f")"
  enc="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$rel")"
  if curl -fsSL --retry 4 -o "$f.part" "$base/$enc"; then
    mv "$f.part" "$f"
    echo "   fetched $rel ($(du -h "$f" | cut -f1))"
  else
    rm -f "$f.part"
    echo "   FAILED to download $rel from $base" >&2
    exit 1
  fi
done
