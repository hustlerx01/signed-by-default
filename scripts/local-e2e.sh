#!/usr/bin/env bash
# Offline end-to-end: build image (ko, no Docker) -> push to throwaway local registry -> SBOM (syft)
# -> sign + attest SBOM (cosign, local key pair, no Rekor) -> verify -> tamper test.
# Keyless (Fulcio/Rekor) signing only happens in GitHub Actions; see .github/workflows/release.yml.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${OUT:-results}; mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd); WORK=$(mktemp -d)
PORT=${PORT:-5055}; REG=localhost:$PORT
export COSIGN_PASSWORD=${COSIGN_PASSWORD:-lab-only-password} COSIGN_YES=true
registry -port "$PORT" >"$WORK/registry.log" 2>&1 & RPID=$!
trap 'kill $RPID 2>/dev/null; rm -rf "$WORK"' EXIT
sleep 1
log(){ echo "== $*" | tee -a "$OUT/e2e.log"; }
: > "$OUT/e2e.log"

log "build+push with ko (base: cgr.dev/chainguard/static via ko default)"
IMG=$(cd app && KO_DOCKER_REPO=$REG/app ko build --bare --sbom=none --platform=linux/amd64 . 2>>"$OUT/e2e.log")
echo "$IMG" | tee -a "$OUT/e2e.log"   # digest-pinned ref

log "SBOM with syft (SPDX JSON)"
syft scan "registry:$IMG" -o spdx-json="$OUT/sbom.spdx.json" -q
python3 -c "import json;d=json.load(open('$OUT/sbom.spdx.json'));print('packages:',len(d['packages']))" | tee -a "$OUT/e2e.log"

log "key pair (lab only; CI uses keyless OIDC)"
(cd "$WORK" && cosign generate-key-pair >/dev/null 2>&1)
SIGN_FLAGS="--tlog-upload=false --use-signing-config=false --allow-insecure-registry"
VERIFY_FLAGS="--insecure-ignore-tlog=true --allow-insecure-registry"

log "sign image"
cosign sign --key "$WORK/cosign.key" $SIGN_FLAGS "$IMG" >>"$OUT/e2e.log" 2>&1
log "attest SBOM"
cosign attest --key "$WORK/cosign.key" --type spdxjson --predicate "$OUT/sbom.spdx.json" $SIGN_FLAGS "$IMG" >>"$OUT/e2e.log" 2>&1

log "verify signature"
cosign verify --key "$WORK/cosign.pub" $VERIFY_FLAGS "$IMG" 2>>"$OUT/e2e.log" | python3 -m json.tool > "$OUT/verify.json"
echo "signature OK" | tee -a "$OUT/e2e.log"
log "verify SBOM attestation"
cosign verify-attestation --key "$WORK/cosign.pub" --type spdxjson $VERIFY_FLAGS "$IMG" > "$WORK/att.json" 2>>"$OUT/e2e.log"
echo "attestation OK" | tee -a "$OUT/e2e.log"

log "NEGATIVE: wrong key must fail"
(cd "$WORK" && mkdir other && cd other && cosign generate-key-pair >/dev/null 2>&1)
if cosign verify --key "$WORK/other/cosign.pub" $VERIFY_FLAGS "$IMG" >/dev/null 2>&1; then echo "FAIL: wrong key verified" | tee -a "$OUT/e2e.log"; exit 1; fi
echo "wrong key rejected: OK" | tee -a "$OUT/e2e.log"

log "NEGATIVE: unsigned image (re-push under new digest) must fail"
NEW=$(cd app && KO_DOCKER_REPO=$REG/app ko build --bare --sbom=none --platform=linux/amd64 --tags tampered . 2>/dev/null)
crane mutate --label tampered=yes "$REG/app:tampered" >/dev/null 2>&1 && TAMPER=$(crane digest "$REG/app:tampered")
if cosign verify --key "$WORK/cosign.pub" $VERIFY_FLAGS "$REG/app@$TAMPER" >/dev/null 2>&1; then echo "FAIL: tampered verified" | tee -a "$OUT/e2e.log"; exit 1; fi
echo "tampered digest $TAMPER rejected: OK" | tee -a "$OUT/e2e.log"
echo "ALL E2E CHECKS PASSED" | tee -a "$OUT/e2e.log"
