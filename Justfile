# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# dictask — Speech-to-Do Pipeline
# https://just.systems/man/en/

set shell := ["bash", "-uc"]
set dotenv-load := true
set positional-arguments := true

# Import auto-generated contractile recipes
import? "contractile.just"

project := "dictask"
version := "0.1.0"
tier := "2"

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT & HELP
# ═══════════════════════════════════════════════════════════════════════════════

# Show all available recipes
default:
    @just --list --unsorted

# Show project info
info:
    @echo "Project: {{project}}"
    @echo "Version: {{version}}"
    @echo "RSR Tier: {{tier}}"
    @echo "Recipes: $(just --summary | wc -w)"
    @[ -f ".machine_readable/STATE.a2ml" ] && grep -oP 'phase\s*=\s*"\K[^"]+' .machine_readable/STATE.a2ml | head -1 | xargs -I{} echo "Phase: {}" || true

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD
# ═══════════════════════════════════════════════════════════════════════════════

# Build all components
build: build-rust build-haskell build-ffi

# Build Rust components (ingest, transcribe, store)
build-rust:
    cd src/ingest && cargo build
    cd src/transcribe && cargo build
    cd src/store && cargo build

# Build Rust components in release mode
build-rust-release:
    cd src/ingest && cargo build --release
    cd src/transcribe && cargo build --release
    cd src/store && cargo build --release

# Build Haskell parser
build-haskell:
    cd src/parse && cabal build

# Build Zig FFI bridge
build-ffi:
    cd src/interface/ffi && zig build

# ═══════════════════════════════════════════════════════════════════════════════
# TEST
# ═══════════════════════════════════════════════════════════════════════════════

# Run all tests
test: test-rust test-haskell test-ffi

# Run Rust tests
test-rust:
    cd src/ingest && cargo test
    cd src/transcribe && cargo test
    cd src/store && cargo test

# Run Haskell parser tests
test-haskell:
    cd src/parse && cabal test

# Run Zig FFI tests
test-ffi:
    cd src/interface/ffi && zig build test

# ═══════════════════════════════════════════════════════════════════════════════
# PIPELINE (manual invocation)
# ═══════════════════════════════════════════════════════════════════════════════

# Run ingest from a mounted recorder path
ingest mount_point="/media/recorder":
    cd src/ingest && cargo run -- "{{mount_point}}"

# Transcribe a specific audio file
transcribe file:
    @echo "STUB: transcription not yet implemented"
    @echo "Would transcribe: {{file}}"

# Parse a transcript file into candidate intents
parse file:
    @echo "STUB: parsing not yet integrated as CLI"
    @echo "Would parse: {{file}}"

# Generate views from canonical SQLite store
views:
    @echo "STUB: view generation not yet implemented"
    @echo "Would generate: Markdown, JSON, CSV views"

# ═══════════════════════════════════════════════════════════════════════════════
# DATABASE
# ═══════════════════════════════════════════════════════════════════════════════

# Initialise SQLite database from schema
db-init:
    #!/usr/bin/env bash
    DB_PATH="${DICTASK_DATA_DIR:-$HOME/.local/share/dictask}/tasks.db"
    mkdir -p "$(dirname "$DB_PATH")"
    sqlite3 "$DB_PATH" ".read schemas/tasks.sql"
    echo "Database initialised at: $DB_PATH"

# Show database stats
db-stats:
    #!/usr/bin/env bash
    DB_PATH="${DICTASK_DATA_DIR:-$HOME/.local/share/dictask}/tasks.db"
    echo "=== dictask Database Stats ==="
    echo "Tasks:      $(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM tasks;' 2>/dev/null || echo 'N/A')"
    echo "Audio:      $(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM audio_files;' 2>/dev/null || echo 'N/A')"
    echo "Transcripts:$(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM transcripts;' 2>/dev/null || echo 'N/A')"
    echo "Intents:    $(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM candidate_intents;' 2>/dev/null || echo 'N/A')"
    echo "Audit log:  $(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM audit_log;' 2>/dev/null || echo 'N/A')"
    echo "Review Q:   $(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM review_queue WHERE resolution IS NULL;' 2>/dev/null || echo 'N/A')"

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOYMENT
# ═══════════════════════════════════════════════════════════════════════════════

# Run Ansible local setup
deploy-local:
    cd deploy/ansible && ansible-playbook setup.yml

# Initialise Terraform
deploy-cloud-init:
    cd deploy/terraform && terraform init

# Apply Terraform (provision cloud resources)
deploy-cloud-apply:
    cd deploy/terraform && terraform apply

# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINER
# ═══════════════════════════════════════════════════════════════════════════════

# Build OCI container image
container-build:
    podman build -t dictask:{{version}} -f Containerfile .

# Run container
container-run:
    podman run --rm -it dictask:{{version}}

# ═══════════════════════════════════════════════════════════════════════════════
# LINT & FORMAT
# ═══════════════════════════════════════════════════════════════════════════════

# Lint all code
lint: lint-rust lint-haskell

# Lint Rust code
lint-rust:
    cd src/ingest && cargo clippy -- -D warnings
    cd src/transcribe && cargo clippy -- -D warnings
    cd src/store && cargo clippy -- -D warnings

# Lint Haskell code
lint-haskell:
    cd src/parse && cabal build --ghc-options="-Wall -Werror"

# Format Rust code
fmt-rust:
    cd src/ingest && cargo fmt
    cd src/transcribe && cargo fmt
    cd src/store && cargo fmt

# ═══════════════════════════════════════════════════════════════════════════════
# CLEAN
# ═══════════════════════════════════════════════════════════════════════════════

# Clean all build artifacts
clean:
    cd src/ingest && cargo clean
    cd src/transcribe && cargo clean
    cd src/store && cargo clean
    cd src/parse && cabal clean
    cd src/interface/ffi && rm -rf zig-out zig-cache

# Run panic-attacker pre-commit scan
assail:
    @command -v panic-attack >/dev/null 2>&1 && panic-attack assail . || echo "panic-attack not found — install from https://github.com/hyperpolymath/panic-attacker"

# ═══════════════════════════════════════════════════════════════════════════════
# ONBOARDING & DIAGNOSTICS
# ═══════════════════════════════════════════════════════════════════════════════

# Check all required toolchain dependencies and report health
doctor:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Dictask Doctor — Toolchain Health Check"
    echo "═══════════════════════════════════════════════════"
    echo ""
    PASS=0; FAIL=0; WARN=0
    check() {
        local name="$1" cmd="$2" min="$3"
        if command -v "$cmd" >/dev/null 2>&1; then
            VER=$("$cmd" --version 2>&1 | head -1)
            echo "  [OK]   $name — $VER"
            PASS=$((PASS + 1))
        else
            echo "  [FAIL] $name — not found (need $min+)"
            FAIL=$((FAIL + 1))
        fi
    }
    check "just"              just      "1.25" 
    check "git"               git       "2.40" 
# Optional tools
if command -v panic-attack >/dev/null 2>&1; then
    echo "  [OK]   panic-attack — available"
    PASS=$((PASS + 1))
else
    echo "  [WARN] panic-attack — not found (pre-commit scanner)"
    WARN=$((WARN + 1))
fi
    echo ""
    echo "  Result: $PASS passed, $FAIL failed, $WARN warnings"
    if [ "$FAIL" -gt 0 ]; then
        echo "  Run 'just heal' to attempt automatic repair."
        exit 1
    fi
    echo "  All required tools present."

# Attempt to automatically install missing tools
heal:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Dictask Heal — Automatic Tool Installation"
    echo "═══════════════════════════════════════════════════"
    echo ""
if ! command -v just >/dev/null 2>&1; then
    echo "Installing just..."
    cargo install just 2>/dev/null || echo "Install just from https://just.systems"
fi
    echo ""
    echo "Heal complete. Run 'just doctor' to verify."

# Guided tour of the project structure and key concepts
tour:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Dictask — Guided Tour"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo '// SPDX-License-Identifier: MPL-2.0'
    echo ""
    echo "Key directories:"
    echo "  src/                      Source code" 
    echo "  docs/                     Documentation" 
    echo "  tests/                    Test suite" 
    echo "  .github/workflows/        CI/CD workflows" 
    echo "  .machine_readable/        Machine-readable metadata" 
    echo "  container/                Container configuration" 
    echo "  examples/                 Usage examples" 
    echo ""
    echo "Quick commands:"
    echo "  just doctor    Check toolchain health"
    echo "  just heal      Fix missing tools"
    echo "  just help-me   Common workflows"
    echo "  just default   List all recipes"
    echo ""
    echo "Read more: README.adoc, EXPLAINME.adoc"

# Show help for common workflows
help-me:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Dictask — Common Workflows"
    echo "═══════════════════════════════════════════════════"
    echo ""
echo "FIRST TIME SETUP:"
echo "  just doctor           Check toolchain"
echo "  just heal             Fix missing tools"
echo "" 
echo "PRE-COMMIT:"
echo "  just assail           Run panic-attacker scan"
echo ""
echo "LEARN:"
echo "  just tour             Guided project tour"
echo "  just default          List all recipes" 


# Print the current CRG grade (reads from READINESS.md '**Current Grade:** X' line)
crg-grade:
    @grade=$$(grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md 2>/dev/null | head -1); \
    [ -z "$$grade" ] && grade="X"; \
    echo "$$grade"

# Generate a shields.io badge markdown for the current CRG grade
# Looks for '**Current Grade:** X' in READINESS.md; falls back to X
crg-badge:
    @grade=$$(grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md 2>/dev/null | head -1); \
    [ -z "$$grade" ] && grade="X"; \
    case "$$grade" in \
      A) color="brightgreen" ;; B) color="green" ;; C) color="yellow" ;; \
      D) color="orange" ;; E) color="red" ;; F) color="critical" ;; \
      *) color="lightgrey" ;; esac; \
    echo "[![CRG $$grade](https://img.shields.io/badge/CRG-$$grade-$$color?style=flat-square)](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)"
