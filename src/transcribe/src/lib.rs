// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
//! dictask transcription: offline ASR using Whisper or Vosk.
//!
//! Pipeline stage 4: Convert audio files to text transcripts.
//! Produces structured JSON with word-level timing and confidence.

#![forbid(unsafe_code)]
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// A segment of transcribed text with timing information.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TranscriptSegment {
    pub start_seconds: f64,
    pub end_seconds: f64,
    pub text: String,
    pub confidence: f64,
}

/// A complete transcript of an audio file.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transcript {
    pub id: Uuid,
    pub audio_file_id: Uuid,
    pub engine_name: String,
    pub engine_version: String,
    pub full_text: String,
    pub segments: Vec<TranscriptSegment>,
    pub language_detected: Option<String>,
    pub quality_score: Option<f64>,
}

/// ASR engine selection.
#[derive(Debug, Clone, Copy)]
pub enum AsrEngine {
    /// OpenAI Whisper (via whisper-rs) — higher accuracy, slower
    Whisper,
    /// Vosk — faster, fully offline, lower accuracy
    Vosk,
}

/// Transcribe an audio file.
///
/// STUB: Full implementation will:
/// 1. Load the audio file (WAV/MP3/etc.)
/// 2. Run through selected ASR engine
/// 3. Produce segments with word-level timing
/// 4. Compute overall quality score
/// 5. Return structured Transcript
pub fn transcribe(
    _audio_path: &std::path::Path,
    _audio_file_id: Uuid,
    _engine: AsrEngine,
) -> anyhow::Result<Transcript> {
    // STUB: Return empty transcript for now
    Ok(Transcript {
        id: Uuid::now_v7(),
        audio_file_id: _audio_file_id,
        engine_name: match _engine {
            AsrEngine::Whisper => "whisper".to_string(),
            AsrEngine::Vosk => "vosk".to_string(),
        },
        engine_version: "stub-0.0.0".to_string(),
        full_text: String::new(),
        segments: Vec::new(),
        language_detected: Some("en".to_string()),
        quality_score: None,
    })
}
