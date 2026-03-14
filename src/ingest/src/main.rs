// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
//! dictask ingest: detect recorder, archive audio files, compute checksums.
//!
//! Pipeline stages 1-3:
//! 1. Detect recorder USB insertion (triggered by udev/systemd)
//! 2. Archive raw audio files with SHA-256 checksums
//! 3. Upload encrypted backup to cloud (retry 3x / quarantine)

use anyhow::Result;
use sha2::{Digest, Sha256};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use tracing::{error, info, warn};
use uuid::Uuid;
use walkdir::WalkDir;

/// Audio file metadata after ingestion.
#[derive(Debug)]
struct IngestedFile {
    id: Uuid,
    original_path: PathBuf,
    archive_path: PathBuf,
    sha256_hash: String,
    file_size: u64,
}

/// Find audio files on the mounted recorder.
fn discover_audio_files(mount_point: &Path) -> Vec<PathBuf> {
    let audio_extensions = ["wav", "mp3", "m4a", "ogg", "flac", "wma", "aac"];

    WalkDir::new(mount_point)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .filter(|e| {
            e.path()
                .extension()
                .and_then(|ext| ext.to_str())
                .map(|ext| audio_extensions.contains(&ext.to_lowercase().as_str()))
                .unwrap_or(false)
        })
        .map(|e| e.into_path())
        .collect()
}

/// Compute SHA-256 hash of a file.
fn compute_sha256(path: &Path) -> Result<String> {
    let bytes = fs::read(path)?;
    let hash = Sha256::digest(&bytes);
    Ok(format!("{:x}", hash))
}

/// Archive a single audio file: copy to archive dir with UUID name, compute hash.
fn archive_file(source: &Path, archive_dir: &Path) -> Result<IngestedFile> {
    let id = Uuid::now_v7();
    let extension = source
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("wav");
    let archive_name = format!("{}.{}", id, extension);
    let archive_path = archive_dir.join(&archive_name);

    // Compute hash before copying (content-addressable dedup)
    let sha256_hash = compute_sha256(source)?;
    let file_size = fs::metadata(source)?.len();

    // Copy to archive
    fs::copy(source, &archive_path)?;

    info!(
        file = %source.display(),
        hash = %sha256_hash,
        size = file_size,
        "Archived audio file"
    );

    Ok(IngestedFile {
        id,
        original_path: source.to_path_buf(),
        archive_path,
        sha256_hash,
        file_size,
    })
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::init();

    let data_dir = env::var("DICTASK_DATA_DIR")
        .unwrap_or_else(|_| {
            let home = env::var("HOME").expect("HOME not set");
            format!("{}/.local/share/dictask", home)
        });
    let archive_dir = PathBuf::from(&data_dir).join("audio-archive");

    // Ensure archive directory exists
    fs::create_dir_all(&archive_dir)?;

    // STUB: In production, mount_point comes from udev/systemd environment
    let mount_point = env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            warn!("No mount point provided; use: dictask-ingest /path/to/recorder");
            PathBuf::from("/media/recorder")
        });

    info!(mount_point = %mount_point.display(), "Starting ingest");

    let audio_files = discover_audio_files(&mount_point);
    info!(count = audio_files.len(), "Discovered audio files");

    let mut ingested = Vec::new();
    for file in &audio_files {
        match archive_file(file, &archive_dir) {
            Ok(record) => ingested.push(record),
            Err(e) => error!(file = %file.display(), error = %e, "Failed to archive file"),
        }
    }

    info!(
        total = audio_files.len(),
        archived = ingested.len(),
        "Ingest complete"
    );

    // STUB: Next stages would be:
    // 1. Insert records into SQLite (audio_files table)
    // 2. Trigger cloud backup for each file
    // 3. Trigger transcription pipeline

    Ok(())
}
