#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# julia_mint_test.sh — e2e: the julia-library overlay mints a working package.
#
# Simulates `just repo-init julia-library` end to end (overlay copy ->
# token substitution -> .in renames -> placeholder gate -> lock coverage ->
# Pkg.instantiate -> Pkg.test -> uuid derivation checks), on the real
# toolchain. This is the acceptance test for the overlay and for the two
# repo-init hunks it depends on (PACKAGE_UUID derivation; .in renames).
#
# Owner rulings exercised here (2026-09-19):
#   D7  - the package uuid is generated at mint (derived, stable, v5)
#   D6  - the minted workflows are lock-SSOT compliant (actions.lock ships)
#
# Usage:
#   JULIA_BIN=/path/to/julia bash tests/e2e/julia_mint_test.sh
#   (JULIA_BIN defaults to `julia` on PATH; the estate runner pins it via
#    julia-actions/setup-julia)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OVERLAY="$REPO_DIR/archetypes/julia-library/overlay"
JULIA="${JULIA_BIN:-julia}"
SCRATCH="${SCRATCH:-$(mktemp -d /tmp/julia-mint-test.XXXXXX)}"
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

command -v "$JULIA" >/dev/null 2>&1 || { echo "SKIP: no julia binary (JULIA_BIN)"; exit 0; }
[ -d "$OVERLAY" ] || { echo "FAIL: overlay not found at $OVERLAY"; exit 1; }

cd "$SCRATCH"

# ── 1. overlay copy (as repo-init does) ────────────────────────────────
cp -a "$OVERLAY/." .

# ── 2. token substitution (as repo-init does) + hunk A (uuid derivation)
OWNER=hyperpolymath; REPO=mintcheck; PROJECT_NAME=MintCheck
AUTHOR="Jonathan D.A. Jewell"; AUTHOR_EMAIL="owner@hyperpolymath.dev"
FORGE=https://github.com; CURRENT_YEAR=$(date +%Y)
LB='{{'; RB='}}'
REPO_UUID=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_URL, '${FORGE}/${OWNER}/${REPO}'))")
if command -v uuidgen >/dev/null 2>&1; then
    PACKAGE_UUID=$(uuidgen --sha1 --namespace "$REPO_UUID" --name "julia:${REPO}")
else
    PACKAGE_UUID=$(python3 -c "import uuid; print(uuid.uuid5(uuid.UUID('${REPO_UUID}'), 'julia:${REPO}'))")
fi
for f in $(grep -rl "{{" . 2>/dev/null || true); do
    tmp=$(mktemp)
    sed -e "s|${LB}PROJECT_NAME${RB}|${PROJECT_NAME}|g" \
        -e "s|${LB}OWNER${RB}|${OWNER}|g" \
        -e "s|${LB}CURRENT_YEAR${RB}|${CURRENT_YEAR}|g" \
        -e "s|${LB}PACKAGE_UUID${RB}|${PACKAGE_UUID}|g" \
        -e "s|${LB}AUTHOR${RB}|${AUTHOR}|g" \
        -e "s|${LB}AUTHOR_EMAIL${RB}|${AUTHOR_EMAIL}|g" \
        -e "s|${LB}PROJECT_DESCRIPTION${RB}|Mint check of the julia-library archetype overlay.|g" \
        "$f" > "$tmp" && mv "$tmp" "$f"
done

# ── 3. rename rule (patch hunk B) ──────────────────────────────────────
TOML_FILE=Project.toml
[ -f "$TOML_FILE" ] || TOML_FILE=Project.toml.in
if [ -f src/PACKAGE.jl.in ] && [ -f "$TOML_FILE" ]; then
    PKG_NAME=$(sed -n 's/^name = "\([^"]*\)".*/\1/p' "$TOML_FILE" | head -1)
    [ -n "$PKG_NAME" ] && [ "$PKG_NAME" != "UNASSIGNED" ] && mv "src/PACKAGE.jl.in" "src/${PKG_NAME}.jl"
fi
for f in Project.toml.in .github/workflows/julia-ci.yml.in .github/workflows/julia-docs.yml.in; do
    [ -f "$f" ] && mv "$f" "${f%.in}"
done

# ── 4. placeholder gate (roster only — GHA ${{ }} is not a token) ─────
if grep -rnE "${LB}(PROJECT_NAME|PROJECT_DESCRIPTION|OWNER|AUTHOR|AUTHOR_EMAIL|CURRENT_YEAR|PACKAGE_UUID|REPO|FORGE)${RB}" . 2>/dev/null; then
    bad "unfilled template tokens remain"
else
    ok "no unfilled tokens"
fi

# ── 4b. lock coverage (D6: actions.lock is the pin truth) ──────────────
if python3 - <<'PY'
import re, sys, pathlib
wfdir = pathlib.Path(".github/workflows")
lock_text = (wfdir / "actions.lock").read_text()
for wf in sorted(wfdir.glob("*.yml")):
    uses = {m.group(1) for line in wf.read_text().splitlines()
            if (m := re.match(r'\s*uses:\s*(\S+)', line))}
    sect = re.search(r"'" + re.escape(str(wf)) + r"':\s*\n((?:\s+-\s+'[^']+'\n?)*)", lock_text)
    locked = set(re.findall(r"-\s+'([^']+)'", sect.group(1))) if sect else set()
    if uses - locked:
        print(f"  MISSING in lock: {wf.name}: {sorted(uses - locked)}")
        sys.exit(1)
PY
then ok "every uses: ref is in actions.lock"; else bad "lockfile coverage gap"; fi

# ── 5. Pkg.instantiate + Pkg.test (Test + Aqua) ────────────────────────
if "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' >/tmp/julia-mint-inst.log 2>&1; then
    ok "Pkg.instantiate"
else
    bad "Pkg.instantiate (see /tmp/julia-mint-inst.log)"; tail -5 /tmp/julia-mint-inst.log
fi
if "$JULIA" --project=. -e 'using Pkg; Pkg.test()' >/tmp/julia-mint-test.log 2>&1; then
    ok "Pkg.test (Test + Aqua)"
else
    bad "Pkg.test (see /tmp/julia-mint-test.log)"; tail -8 /tmp/julia-mint-test.log
fi

# ── 6. uuid derivation (D7) ────────────────────────────────────────────
MINTED_UUID=$(sed -n 's/^uuid = "\(.*\)".*/\1/p' Project.toml | head -1)
if python3 - "$MINTED_UUID" "$PACKAGE_UUID" <<'PY'
import sys, uuid
minted, derived = sys.argv[1], sys.argv[2]
assert minted == derived, f"minted {minted} != derived {derived}"
assert uuid.UUID(minted).version == 5
PY
then ok "package uuid is the derived v5"; else bad "package uuid derivation"; fi
RE_MINT=$(python3 -c "import uuid; print(uuid.uuid5(uuid.UUID('${REPO_UUID}'), 'julia:${REPO}'))")
[ "$RE_MINT" = "$MINTED_UUID" ] && ok "re-mint derives the same uuid (stable identity)" || bad "uuid not stable across re-mints"

echo
echo "julia mint test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
