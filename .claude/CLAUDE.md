# dictask — Project AI Instructions

## Overview

dictask is a speech-to-do pipeline that converts voice recordings from a portable
recorder into structured, prioritised, auditable tasks stored in SQLite.

## Build Commands

```bash
just build           # Build all components
just test            # Run all tests
just build-rust      # Rust only (ingest, transcribe, store)
just build-haskell   # Haskell parser only
just build-ffi       # Zig FFI only
just db-init         # Initialise SQLite from schemas/tasks.sql
```

## Language Map

| Directory | Language | Purpose |
|-----------|----------|---------|
| `src/ingest/` | Rust | udev detection, audio archival, cloud backup |
| `src/transcribe/` | Rust | Whisper/Vosk ASR integration |
| `src/parse/` | Haskell (megaparsec) | NLP task extraction from transcripts |
| `src/store/` | Rust (rusqlite) | SQLite canonical store + view generation |
| `src/review/` | Rust | Review queue + notifications |
| `src/interface/abi/` | Idris2 | Formal ABI proofs for task schema |
| `src/interface/ffi/` | Zig | C-compatible FFI bridge |
| `schemas/` | SQL + JSON | SQLite schema, JSON schemas for intermediate formats |
| `deploy/ansible/` | YAML | Local machine setup |
| `deploy/terraform/` | HCL | Cloud provisioning |

## Key Invariants

1. **Confidence thresholds**: >= 0.8 auto-apply, 0.3–0.8 review, < 0.3 log only
2. **Deletions always review**: DeleteTask confidence capped at 0.7 (never auto-apply)
3. **Idempotent stages**: Same input → same output for all pipeline stages
4. **No Python**: Use Rust, Haskell, Julia, or Zig
5. **Priority formula**: `urgency * 0.5 + importance * 0.3 + deadline_proximity * 0.2`

## Testing

- Haskell: `cd src/parse && cabal test` (HSpec + QuickCheck)
- Rust: `cd src/<component> && cargo test`
- Zig: `cd src/interface/ffi && zig build test`
- Idris2: Compile-time verification (proofs, not runtime tests)
