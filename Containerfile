# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Containerfile for dictask
# Build: podman build -t dictask:latest -f Containerfile .
# Run:   podman run --rm -it dictask:latest
# Seal:  selur seal dictask:latest

# --- Build stage (Rust components) ---
FROM cgr.dev/chainguard/wolfi-base:latest AS build-rust

RUN apk add --no-cache rust cargo sqlite-dev

WORKDIR /build
COPY src/ingest/ src/ingest/
COPY src/transcribe/ src/transcribe/
COPY src/store/ src/store/
COPY schemas/ schemas/

RUN cd src/ingest && cargo build --release
RUN cd src/store && cargo build --release

# --- Runtime stage ---
FROM cgr.dev/chainguard/wolfi-base:latest

RUN apk add --no-cache sqlite

COPY --from=build-rust /build/src/ingest/target/release/dictask-ingest /usr/local/bin/
COPY --from=build-rust /build/src/store/target/release/dictask-store /usr/local/bin/
COPY schemas/ /opt/dictask/schemas/

# Data directory
RUN mkdir -p /data/dictask && chown nonroot:nonroot /data/dictask

ENV DICTASK_DATA_DIR=/data/dictask
ENV DICTASK_DB_PATH=/data/dictask/tasks.db

USER nonroot
VOLUME ["/data/dictask"]

ENTRYPOINT ["/usr/local/bin/dictask-ingest"]
