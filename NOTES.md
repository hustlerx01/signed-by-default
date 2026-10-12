# NOTES
- 2026-10-11: offline e2e green (ko + go-containerregistry `registry` replaced Docker). cosign v3.1.3 needed `--use-signing-config=false --tlog-upload=false` for key-pair signing without Rekor.
- Kyverno CLI caught a real bug: an attestation keyless attestor needs `rekor.url` or `roots`.
- Interview angles: a signature proves *who* signed, provenance proves *how/where* it was built (SLSA). Keyless means no long-lived key to leak, and identity is pinned via the cert SAN plus the OIDC issuer. Rekor = tamper-evident public log. xz = malicious maintainer, so provenance of source matters too.
- Next: push to GitHub, tag v0.1.0, capture the Rekor log index, run kind + Kyverno for the admit/deny demo, add a grype gate.
