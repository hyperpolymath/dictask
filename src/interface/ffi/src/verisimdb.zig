// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// dictask :: src/interface/ffi/src/verisimdb.zig
//
// VeriSimDB persistence client for extracted task store.
//
// Dual-writes task records to VeriSimDB (collection: dictask:tasks) alongside
// the primary SQLite store. This enables Hypatia analysis of task patterns
// across recording sessions and cross-device sync via VeriSimDB replication.
//
// ## Collection schema (dictask:tasks)
//
// ```json
// {
//   "task_id":      "dt:1740000000000:a1b2c3d4",
//   "timestamp":    "2026-01-30T12:00:00Z",
//   "text":         "buy oat milk",
//   "priority":     2,
//   "confidence":   0.94,
//   "source_file":  "REC_20260130.mp3",
//   "status":       "pending",
//   "deduplicated": false
// }
// ```
//
// ## Environment
//
// Set `VERISIMDB_URL` to override the default `http://localhost:8080`.
//
// ## Dual-write semantics
//
// SQLite is the primary store for reliability and offline use.
// VeriSimDB is the secondary store for distributed analysis and sync.
// If VeriSimDB is unreachable, `persistTask` returns an error and the
// caller continues with SQLite-only storage.

const std = @import("std");

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_URL = "http://localhost:8080";
const COLLECTION  = "dictask:tasks";

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// A single extracted task record for VeriSimDB persistence.
pub const TaskRecord = struct {
    task_id:      []const u8,
    timestamp:    []const u8,
    text:         []const u8,
    priority:     u8,          // 1 (highest) to 5 (lowest)
    confidence:   f32,         // 0.0 to 1.0 from transcription model
    source_file:  []const u8,
    status:       []const u8,  // "pending", "done", "archived"
    deduplicated: bool,
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Dual-write a task record to VeriSimDB (collection: dictask:tasks).
///
/// Uses HTTP PUT to `/v1/dictask:tasks/<task_id>`.
/// Fail-open: caller should log the error and continue with SQLite.
pub fn persistTask(allocator: std.mem.Allocator, task: TaskRecord) !void {
    const base_url = std.posix.getenv("VERISIMDB_URL") orelse DEFAULT_URL;

    const url = try std.fmt.allocPrint(allocator, "{s}/v1/{s}/{s}", .{
        base_url, COLLECTION, task.task_id,
    });
    defer allocator.free(url);

    // Format confidence as a fixed-point string (2 decimal places)
    const dedup_str = if (task.deduplicated) "true" else "false";

    const body = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "task_id": "{s}",
        \\  "timestamp": "{s}",
        \\  "text": "{s}",
        \\  "priority": {d},
        \\  "confidence": {d:.2},
        \\  "source_file": "{s}",
        \\  "status": "{s}",
        \\  "deduplicated": {s}
        \\}}
    , .{
        task.task_id,
        task.timestamp,
        task.text,
        task.priority,
        task.confidence,
        task.source_file,
        task.status,
        dedup_str,
    });
    defer allocator.free(body);

    try httpPut(allocator, url, body);
}

/// Generate a stable task ID from source file and timestamp milliseconds.
///
/// Format: `dt:<ts_ms>:<first_8_of_source_sha256_hex>`
pub fn makeTaskId(allocator: std.mem.Allocator, source_file: []const u8, ts_ms: u64) ![]u8 {
    var hash_buf: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source_file, &hash_buf, .{});
    const hex = try std.fmt.allocPrint(allocator, "{}", .{std.fmt.fmtSliceHexLower(hash_buf[0..4])});
    defer allocator.free(hex);
    return std.fmt.allocPrint(allocator, "dt:{d}:{s}", .{ ts_ms, hex });
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn httpPut(allocator: std.mem.Allocator, url: []const u8, body: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);

    var header_buf: [4096]u8 = undefined;
    var req = try client.open(.PUT, uri, .{
        .server_header_buffer = &header_buf,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    try req.send();
    try req.writeAll(body);
    try req.finish();
    try req.wait();

    const status = req.response.status;
    if (@intFromEnum(status) < 200 or @intFromEnum(status) >= 300) {
        return error.VeriSimDbHttpError;
    }
}
