#!/usr/bin/env bash
# Offline-ish admission test of the Kyverno policy with the kyverno CLI (no cluster).
set -uo pipefail; cd "$(dirname "$0")/.."
mk(){ printf 'apiVersion: v1\nkind: Pod\nmetadata: {name: %s}\nspec: {containers: [{name: a, image: %s}]}\n' "$1" "$2"; }
T=$(mktemp -d); mk other nginx:1.27 > $T/other.yaml; mk unsigned ghcr.io/ansarshaikh/unsigned:latest > $T/unsigned.yaml
echo "# out-of-scope image (expect: no rule applied)"; kyverno apply policy/kyverno-verify-images.yaml -r $T/other.yaml 2>&1 | tail -1
echo "# in-scope unsigned image (expect: fail)"; out=$(kyverno apply policy/kyverno-verify-images.yaml -r $T/unsigned.yaml 2>&1); echo "$out" | tail -1
echo "$out" | grep -q "fail: [1-9]" && echo "unsigned image denied: OK"
