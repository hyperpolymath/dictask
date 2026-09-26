// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// dicta-task FFI integration tests: exercise the exported C ABI exactly as a
// Rust/C consumer would, and pin the invariants declared in Abi/Task.idr.
const std = @import("std");
const testing = std.testing;
const ffi = @import("dicta_task_ffi");

test "confidence is clamped to [0,1]" {
    try testing.expectEqual(@as(f64, 1.0), ffi.dicta_task_confidence_new(7.0));
    try testing.expectEqual(@as(f64, 0.0), ffi.dicta_task_confidence_new(-3.0));
    try testing.expectEqual(@as(f64, 0.42), ffi.dicta_task_confidence_new(0.42));
}

test "confidence bands partition [0,1] with no gaps or overlaps" {
    var i: usize = 0;
    while (i <= 100) : (i += 1) {
        const v = @as(f64, @floatFromInt(i)) / 100.0;
        var bands: u8 = 0;
        if (ffi.dicta_task_confidence_is_high(v)) bands += 1;
        if (ffi.dicta_task_confidence_is_medium(v)) bands += 1;
        if (ffi.dicta_task_confidence_is_low(v)) bands += 1;
        try testing.expectEqual(@as(u8, 1), bands);
    }
}

test "confidence band boundaries (0.3 medium, 0.8 high)" {
    try testing.expect(ffi.dicta_task_confidence_is_low(0.2999));
    try testing.expect(ffi.dicta_task_confidence_is_medium(0.3));
    try testing.expect(ffi.dicta_task_confidence_is_medium(0.7999));
    try testing.expect(ffi.dicta_task_confidence_is_high(0.8));
}

test "priority = 0.5*urgency + 0.3*importance + 0.2*deadline" {
    try testing.expectApproxEqAbs(@as(f64, 1.0), ffi.dicta_task_priority_compute(1, 1, 1), 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.0), ffi.dicta_task_priority_compute(0, 0, 0), 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.5), ffi.dicta_task_priority_compute(1, 0, 0), 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.3), ffi.dicta_task_priority_compute(0, 1, 0), 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.2), ffi.dicta_task_priority_compute(0, 0, 1), 1e-12);
}

test "enum discriminants match SQLite CHECK / Idris2 ABI ordering" {
    try testing.expectEqual(@as(u8, 0), @intFromEnum(ffi.TaskStatus.pending));
    try testing.expectEqual(@as(u8, 4), @intFromEnum(ffi.TaskStatus.cancelled));
    try testing.expectEqual(@as(u8, 2), @intFromEnum(ffi.ReviewState.rejected));
    try testing.expectEqual(@as(u8, 6), @intFromEnum(ffi.IntentType.note));
}
