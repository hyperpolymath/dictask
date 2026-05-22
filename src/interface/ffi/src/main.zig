// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Zig FFI bridge for dictask — C-compatible interface between
// Idris2 ABI definitions and Rust consumer components.

const std = @import("std");

// ============================================================================
// Task Status (mirrors Idris2 ABI)
// ============================================================================

pub const TaskStatus = enum(u8) {
    pending = 0,
    in_progress = 1,
    done = 2,
    review_needed = 3,
    cancelled = 4,
};

pub const ReviewState = enum(u8) {
    pending_review = 0,
    approved = 1,
    rejected = 2,
};

pub const IntentType = enum(u8) {
    add_task = 0,
    update_task = 1,
    delete_task = 2,
    set_deadline = 3,
    set_priority = 4,
    add_tag = 5,
    note = 6,
};

// ============================================================================
// Confidence (bounded [0.0, 1.0])
// ============================================================================

pub const Confidence = struct {
    value: f64,

    pub fn init(v: f64) Confidence {
        return .{ .value = @max(0.0, @min(1.0, v)) };
    }

    pub fn isHigh(self: Confidence) bool {
        return self.value >= 0.8;
    }

    pub fn isMedium(self: Confidence) bool {
        return self.value >= 0.3 and self.value < 0.8;
    }

    pub fn isLow(self: Confidence) bool {
        return self.value < 0.3;
    }
};

// ============================================================================
// Priority Score
// ============================================================================

pub const PriorityScore = struct {
    urgency: f64,
    importance: f64,
    deadline_proximity: f64,

    pub fn compute(self: PriorityScore) f64 {
        return self.urgency * 0.5 + self.importance * 0.3 + self.deadline_proximity * 0.2;
    }
};

// ============================================================================
// C-compatible Task struct (for FFI)
// ============================================================================

pub const CTask = extern struct {
    id: [36]u8, // UUID string (36 chars)
    title_ptr: [*c]const u8,
    title_len: usize,
    description_ptr: [*c]const u8, // NULL if no description
    description_len: usize,
    status: TaskStatus,
    priority_urgency: f64,
    priority_importance: f64,
    priority_deadline_proximity: f64,
    due_date_ptr: [*c]const u8, // ISO 8601, NULL if none
    due_date_len: usize,
    due_date_tentative: bool,
    review_state: ReviewState,
    confidence: f64,
};

pub const CCandidateIntent = extern struct {
    id: [36]u8,
    transcript_id: [36]u8,
    parser_version_ptr: [*c]const u8,
    parser_version_len: usize,
    intent_type: IntentType,
    raw_text_ptr: [*c]const u8,
    raw_text_len: usize,
    confidence: f64,
    review_required: bool,
};

// ============================================================================
// Exported C functions
// ============================================================================

/// Create a new Confidence value, clamped to [0.0, 1.0].
export fn dictask_confidence_new(value: f64) f64 {
    return Confidence.init(value).value;
}

/// Check if confidence is high (>= 0.8).
export fn dictask_confidence_is_high(value: f64) bool {
    return Confidence.init(value).isHigh();
}

/// Check if confidence is medium (0.3-0.8).
export fn dictask_confidence_is_medium(value: f64) bool {
    return Confidence.init(value).isMedium();
}

/// Check if confidence is low (< 0.3).
export fn dictask_confidence_is_low(value: f64) bool {
    return Confidence.init(value).isLow();
}

/// Compute priority score from weighted components.
export fn dictask_priority_compute(urgency: f64, importance: f64, deadline_proximity: f64) f64 {
    const ps = PriorityScore{
        .urgency = urgency,
        .importance = importance,
        .deadline_proximity = deadline_proximity,
    };
    return ps.compute();
}

// ============================================================================
// Tests
// ============================================================================

test "confidence clamping" {
    const c1 = Confidence.init(1.5);
    try std.testing.expectEqual(c1.value, 1.0);

    const c2 = Confidence.init(-0.5);
    try std.testing.expectEqual(c2.value, 0.0);

    const c3 = Confidence.init(0.75);
    try std.testing.expectEqual(c3.value, 0.75);
}

test "confidence thresholds" {
    try std.testing.expect(Confidence.init(0.9).isHigh());
    try std.testing.expect(Confidence.init(0.5).isMedium());
    try std.testing.expect(Confidence.init(0.1).isLow());
    try std.testing.expect(!Confidence.init(0.5).isHigh());
    try std.testing.expect(!Confidence.init(0.9).isMedium());
}

test "priority computation" {
    const ps = PriorityScore{
        .urgency = 1.0,
        .importance = 1.0,
        .deadline_proximity = 1.0,
    };
    try std.testing.expectEqual(ps.compute(), 1.0);

    const ps2 = PriorityScore{
        .urgency = 0.0,
        .importance = 0.0,
        .deadline_proximity = 0.0,
    };
    try std.testing.expectEqual(ps2.compute(), 0.0);
}
