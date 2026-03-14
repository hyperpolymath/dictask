# SPDX-License-Identifier: PMPL-1.0-or-later

# dictask — Architecture Topology

## System Architecture

```
                         ┌─────────────────┐
                         │  Portable Voice  │
                         │    Recorder      │
                         └────────┬────────┘
                                  │ USB
                         ┌────────▼────────┐
                         │  [1] udev/      │
                         │  systemd detect │
                         └────────┬────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │  [2] Ingest (Rust)         │
                    │  • Archive raw audio       │
                    │  • SHA-256 checksum        │
                    │  • File metadata           │
                    └─────┬───────────────┬─────┘
                          │               │
               ┌──────────▼──────┐  ┌─────▼──────────────┐
               │ [3] Cloud       │  │ [4] Transcribe     │
               │ Backup          │  │ (Rust + Whisper/    │
               │ (encrypted,     │  │  Vosk)             │
               │  retry 3x)      │  │ → transcript.json  │
               └─────────────────┘  └─────────┬──────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │ [5] Parse            │
                                   │ (Haskell megaparsec) │
                                   │ → candidate intents  │
                                   │   with confidence    │
                                   └──────────┬──────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │ [6] Normalise        │
                                   │ • Resolve dates      │
                                   │ • Priority scoring   │
                                   │ • Validate fields    │
                                   └──────────┬──────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │ [7] Deduplicate      │
                                   │ • Exact matching     │
                                   │ • Semantic similarity│
                                   │ • Supersedes linking │
                                   └──────────┬──────────┘
                                              │
                              ┌───────────────┴───────────────┐
                              │                               │
                    ┌─────────▼─────────┐          ┌──────────▼─────────┐
                    │ [8a] Auto-Apply    │          │ [8b] Review Queue  │
                    │ (confidence ≥ 0.8) │          │ (confidence < 0.8) │
                    └─────────┬─────────┘          └──────────┬─────────┘
                              │                               │
                              └───────────────┬───────────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │ Canonical Store      │
                                   │ (SQLite + WAL)       │
                                   │ Single source of     │
                                   │ truth for all tasks  │
                                   └──────────┬──────────┘
                                              │
                              ┌───────────────┼───────────────┐
                              │               │               │
                    ┌─────────▼───┐  ┌────────▼────┐  ┌──────▼──────┐
                    │ [9] Views   │  │ [9] Views   │  │ [9] Views   │
                    │ Markdown    │  │ JSON        │  │ CSV         │
                    └─────────────┘  └─────────────┘  └─────────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │ [10] Notify          │
                                   │ Dashboard / Email    │
                                   └─────────────────────┘
```

## Interface Architecture (Verified Seams)

```
┌──────────────────────────────┐
│ Idris2 ABI (src/interface/abi/)│  ← The Specification (dependent types)
│ • Task type with proofs       │
│ • Confidence bounds           │
│ • Schema migration rules      │
└──────────────┬───────────────┘
               │ generates
┌──────────────▼───────────────┐
│ C Headers (generated/)        │  ← The Artifact
└──────────────┬───────────────┘
               │ implements
┌──────────────▼───────────────┐
│ Zig FFI (src/interface/ffi/) │  ← The Bridge (C ABI compatible)
└──────────────┬───────────────┘
               │ links
┌──────────────▼───────────────┐
│ Rust Components               │  ← The Consumers
│ (ingest, transcribe, store,   │
│  review)                      │
└──────────────────────────────┘
```

## Completion Dashboard

| Component              | Progress                       | Status |
|------------------------|--------------------------------|--------|
| Architecture design    | `████████░░` 80%               | Active |
| SQLite schema          | `░░░░░░░░░░` 0%                | —      |
| Idris2 ABI proofs      | `░░░░░░░░░░` 0%                | —      |
| Zig FFI bridge         | `░░░░░░░░░░` 0%                | —      |
| Rust ingest            | `░░░░░░░░░░` 0%                | —      |
| Rust transcription     | `░░░░░░░░░░` 0%                | —      |
| Haskell parser         | `░░░░░░░░░░` 0%                | —      |
| Confidence scoring     | `░░░░░░░░░░` 0%                | —      |
| Deduplication          | `░░░░░░░░░░` 0%                | —      |
| Review queue           | `░░░░░░░░░░` 0%                | —      |
| View generation        | `░░░░░░░░░░` 0%                | —      |
| Ansible deployment     | `░░░░░░░░░░` 0%                | —      |
| Terraform provisioning | `░░░░░░░░░░` 0%                | —      |
| Audit trail            | `░░░░░░░░░░` 0%                | —      |
| CI/CD (Hypatia)        | `░░░░░░░░░░` 0%                | —      |
| **Overall**            | `█░░░░░░░░░` ~5%               | Design |

## Key Dependencies

| Dependency   | Version | Purpose                    |
|-------------|---------|----------------------------|
| whisper-rs   | latest  | Offline ASR (Whisper model) |
| vosk         | latest  | Alternative offline ASR    |
| megaparsec   | 9.x     | Haskell parser combinators |
| rusqlite     | latest  | SQLite bindings for Rust   |
| idris2       | 0.7+    | ABI formal verification    |
| zig          | 0.13+   | FFI bridge                 |
| ansible      | 2.x     | Local deployment           |
| terraform    | 1.x     | Cloud provisioning         |
