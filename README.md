[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/hyperpolymath)

// SPDX-License-Identifier: CC-BY-SA-4.0
= dictask — Speech-to-Do Pipeline
Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
:toc: preamble
:icons: font

[TIP]
====
**AI-Assisted Install:** Just tell any AI assistant: +
`Set up dictask from https://github.com/hyperpolymath/dictask` +
The AI reads the manifest, asks you a few questions, and handles everything.
====

== Overview

**dictask** automates the ingestion of speech notes from a portable voice recorder
into a structured, prioritised, auditable task list.

Plug in your recorder → dictask detects it, archives the audio, transcribes it,
extracts tasks with confidence scores, deduplicates against your existing list,
and either auto-applies high-confidence items or queues ambiguous ones for review.

This project follows a **Dual-Track** architecture:

* **Root:** High-level orientation and rich documentation for humans.
* **Sub-directories:** Machine-readable metadata and technical implementation.

== Architecture

=== Pipeline (10 stages, batch)

[source,plaintext]
----
Recorder USB
  → [1] udev/systemd detect
  → [2] Local archive (SHA-256 checksummed)
  → [3] Encrypted cloud backup (retry 3x / quarantine)
  → [4] Whisper/Vosk transcription → transcript JSON
  → [5] Haskell megaparsec NLP → candidate intents (with confidence)
  → [6] Normalise (resolve dates, assign priority scores)
  → [7] Deduplicate (exact + semantic matching)
  → [8] Review queue (low confidence) or auto-apply (high confidence)
  → [9] Canonical SQLite store → views (Markdown, JSON, CSV)
  → [10] Notify (dashboard / email alerts for review items)
----

=== Components

[cols="1,1,3"]
|===
| Component | Language/Tool | Purpose

| Ingest
| Rust
| Detect recorder insertion (udev), archive audio, compute checksums, upload encrypted backup.

| Transcription
| Rust (whisper-rs / vosk)
| Convert audio to text using offline ASR. No cloud dependency.

| Task Parser
| Haskell (megaparsec)
| Extract tasks, deadlines, priorities from transcripts. Pure functions, idempotent.

| Canonical Store
| Rust + SQLite
| Audited, versioned task database. WAL mode. JSON1 for structured fields.

| Review System
| Rust
| Review queue for low-confidence items. Dashboard alerts.

| ABI / Schema Proofs
| Idris2
| Dependent-type proofs for task schema correctness and confidence thresholds.

| FFI Bridge
| Zig
| C-compatible bridge between Idris2 ABI and Rust components.

| Deployment
| Ansible + Terraform
| Local machine setup (Ansible) + cloud provisioning (Terraform).
|===

== Task Schema

[source,haskell]
----
-- Haskell type (src/parse/)
data Task = Task
  { taskId             :: UUID
  , title              :: Text
  , description        :: Maybe Text
  , sourceAudioId      :: AudioHash     -- SHA-256 of source recording
  , sourceTranscriptId :: TranscriptId  -- reference to transcript version
  , createdAt          :: UTCTime
  , updatedAt          :: UTCTime
  , status             :: TaskStatus    -- Pending | InProgress | Done | ReviewNeeded
  , priorityScore      :: PriorityScore -- urgency * 0.5 + importance * 0.3 + deadline_proximity * 0.2
  , dueDate            :: Maybe Day
  , tags               :: [Text]
  , project            :: Maybe Text
  , supersedesTaskId   :: Maybe UUID    -- links to replaced task
  , duplicateOfTaskId  :: Maybe UUID    -- links to canonical duplicate
  , reviewState        :: ReviewState   -- Approved | PendingReview | Rejected
  , confidence         :: Confidence    -- 0.0–1.0, from parser
  , parserVersion      :: Version       -- which parser version produced this
  }
----

== Policies

=== Confidence & Automation

[cols="1,2,2"]
|===
| Confidence | Threshold | Action

| High
| >= 0.8
| Auto-apply to canonical store

| Medium
| 0.3–0.8
| Queue for human review

| Low
| < 0.3
| Log only, do not create task candidate
|===

=== Human Review Boundaries

Actions that **always** require confirmation:

* Deletions of existing tasks
* Deadline changes on existing tasks
* Low-confidence merges (semantic deduplication)
* Any update to a task marked `Approved`

=== Deduplication

* **Exact match:** Same title + same project → auto-merge
* **Semantic duplicate:** Similar intent, different wording → flag for review
* **Recurring task:** Same task pattern across recordings → link to parent with `supersedesTaskId`

=== Privacy & Retention

* **Raw audio:** Encrypted at rest, retained 30 days locally, cloud backup encrypted
* **Transcripts:** Stored locally only, redacted if sensitive content detected
* **Cloud backups:** Encrypted, configurable retention
* **Secrets:** Managed via rokur (Stapeln), never in code or repo

== Audit Trail

Every task carries its full provenance chain:

[source,plaintext]
----
original_audio_hash (SHA-256)
  → transcript_version (Whisper v3 / Vosk v0.3.45)
  → parser_version (dictask-parse v0.1.0)
  → change_set { timestamp, action, user_confirmation_state }
----

All transformations are logged for reproducibility. Reprocessing the same audio file
with the same parser version MUST produce identical candidate tasks (idempotency).

== Failure & Recovery

[cols="1,2"]
|===
| Failure | Handling

| Failed cloud upload | Retry 3x with exponential backoff, then quarantine locally
| Partial transcription | Flag for review, log incomplete segments
| Corrupted audio file | Skip, log with checksum, alert user
| Low-confidence parse | Route to review queue, never auto-apply
| Dedup false positive | Show both candidates in review queue
|===

All pipeline stages are idempotent — reprocessing the same input produces the same output.

== Repository Structure

[cols="1,3"]
|===
| Directory | Purpose

| `.github/`
| Forge-specific metadata (CODEOWNERS, SECURITY.md, workflows).

| `.machine_readable/`
| Canonical project state (6 a2ml files), bot directives, and AI guides.

| `src/ingest/`
| Rust crate: udev detection, file archival, cloud upload.

| `src/transcribe/`
| Rust crate: Whisper/Vosk ASR integration.

| `src/parse/`
| Haskell package: megaparsec NLP task extraction.

| `src/store/`
| Rust crate: SQLite canonical store + view generation.

| `src/review/`
| Rust crate: review queue + notification.

| `src/interface/`
| Verified Interface Seams (Idris2 ABI, Zig FFI, generated C headers).

| `deploy/ansible/`
| Ansible playbooks for local machine setup.

| `deploy/terraform/`
| Terraform configs for cloud provisioning (bucket, IAM).

| `schemas/`
| SQLite schema, JSON schemas for intermediate formats.

| `container/`
| Stapeln container ecosystem.

| `docs/`
| Technical documentation (architecture, theory, practice).
|===

== Quick Start

[source,bash]
----
just init              # Interactive bootstrap
just build             # Build all components
just test              # Run all tests
just ingest            # Run ingest pipeline manually
just transcribe FILE   # Transcribe a specific audio file
just parse FILE        # Parse a transcript file
just views             # Generate Markdown/JSON/CSV views
just container-build   # Build verified OCI image
----

== Deployment

=== Local Setup (Ansible)

[source,bash]
----
cd deploy/ansible
ansible-playbook setup.yml
----

Sets up: udev rules, systemd service, Rust/Haskell toolchains, SQLite.

=== Cloud Provisioning (Terraform)

[source,bash]
----
cd deploy/terraform
terraform init
terraform apply
----

Provisions: encrypted storage bucket, IAM roles, lifecycle rules.

== Testing

* **Haskell parser:** HSpec + QuickCheck property-based tests
* **Rust components:** `cargo test` with integration tests against real SQLite
* **Pipeline replay:** Re-run historical audio through newer parser versions
* **Idris2 proofs:** Compile-time verification (no runtime tests needed)

== Success Metrics

* % of tasks auto-processed vs. requiring manual review
* False positive/negative rates for intent detection
* Time saved vs. manual note-taking and task entry
* Pipeline end-to-end latency (target: < 5 minutes per recording)

== Documentation

* link:CONTRIBUTING.adoc[Contributing Guide]
* link:ROADMAP.adoc[Roadmap]
* link:TOPOLOGY.md[Architecture Topology]
* link:docs/architecture/[Architecture Details]

== License

SPDX-License-Identifier: CC-BY-SA-4.0 +
See link:LICENSE[LICENSE] and link:docs/legal/[docs/legal/] for details.
