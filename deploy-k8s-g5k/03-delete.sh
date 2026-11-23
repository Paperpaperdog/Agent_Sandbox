#!/bin/bash
set -e

cd "$(dirname "$0")"

number_clusters=$(awk -F '=' '/^number_k8s/ {gsub(/[[:space:]]/, "", $2); print $2}' 00-config.toml)

pids=()
for ((i=0; i<number_clusters; i++)); do
    suffix=$(printf "%02d" "$i")

    echo "Deleting cluster ${suffix}......"

    python3 ./delete-cluster.py "$suffix" &
    pids+=($!)

    sleep 1
done

failed=0
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        failed=1
    fi
done
if [[ "$failed" -ne 0 ]]; then
    echo "One or more cluster deletions failed." >&2
    exit 1
fi

echo "All Kubernetes clusters have been deleted."