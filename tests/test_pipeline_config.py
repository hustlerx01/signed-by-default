"""Static guards so the supply-chain config can't silently regress."""
import pathlib, yaml
ROOT = pathlib.Path(__file__).resolve().parents[1]
rel = yaml.safe_load((ROOT / ".github/workflows/release.yml").read_text())
pol = yaml.safe_load((ROOT / "policy/kyverno-verify-images.yaml").read_text())

def test_least_privilege_default():
    assert rel["permissions"] == {"contents": "read"}

def test_build_has_oidc_for_keyless():
    assert rel["jobs"]["build"]["permissions"]["id-token"] == "write"

def test_no_static_cosign_key_in_release():
    txt = (ROOT / ".github/workflows/release.yml").read_text()
    assert "--key" not in txt and "COSIGN_PRIVATE_KEY" not in txt

def test_sign_by_digest_not_tag():
    steps = rel["jobs"]["build"]["steps"]
    sign = next(s["run"] for s in steps if s.get("name", "").startswith("Keyless sign"))
    assert "steps.build.outputs.ref" in sign  # ref = repo@sha256:...

def test_verify_pins_identity_and_issuer():
    txt = (ROOT / ".github/workflows/release.yml").read_text()
    assert "--certificate-identity-regexp" in txt and "token.actions.githubusercontent.com" in txt

def test_slsa_generator_pinned_by_tag():
    uses = rel["jobs"]["provenance"]["uses"]
    assert uses.startswith("slsa-framework/slsa-github-generator/") and "@v2." in uses

def test_kyverno_enforces_keyless_and_sbom():
    assert pol["spec"]["validationFailureAction"] == "Enforce"
    vi = pol["spec"]["rules"][0]["verifyImages"][0]
    assert vi["required"] and vi["verifyDigest"]
    kl = vi["attestors"][0]["entries"][0]["keyless"]
    assert kl["issuer"] == "https://token.actions.githubusercontent.com" and kl["subjectRegExp"].startswith("^")
    assert vi["attestations"][0]["type"] == "https://spdx.dev/Document"
