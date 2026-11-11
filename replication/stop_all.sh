#!/usr/bin/env bash
# Stop every process this kit may have started (runs, test workers, model server,
# a vLLM install still in progress) and clear leftovers of interrupted runs.
source "$(dirname "$0")/common/env.sh"
for pat in run_all.sh serve_vllm.sh multisallm/run.sh cweval/run.sh run_tests_native \
           "vllm serve" "venvs/vllm" cweval/generate.py cweval/evaluate.py multisallm/generate.py; do
  pkill -f "$pat" 2>/dev/null
done
sleep 4
for pat in run_all.sh serve_vllm.sh "vllm serve" run_tests_native; do pkill -9 -f "$pat" 2>/dev/null; done
rm -f "$WORK/vllm.pid" "$WORK/run_all.lock" "$WORK"/published/Filtered_Output/*.part
rm -rf "$WORK"/SALLM/Evaluation/temp_*
left="$(pgrep -fa 'run_all.sh|serve_vllm|vllm serve|run_tests_native|multisallm/run.sh' || true)"
if [ -n "$left" ]; then echo "Still running:"; echo "$left"; else echo "All stopped."; fi
nvidia-smi --query-gpu=index,memory.used --format=csv,noheader 2>/dev/null
