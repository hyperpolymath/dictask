// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// dicta-task FFI build (Zig 0.15+ module API).
//   zig build          -> libdicta_task_ffi (shared + static)
//   zig build test     -> unit tests (src/main.zig) + integration tests (test/)
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ffi_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const shared = b.addLibrary(.{ .name = "dicta_task_ffi", .linkage = .dynamic, .root_module = ffi_mod });
    b.installArtifact(shared);
    const static = b.addLibrary(.{ .name = "dicta_task_ffi", .linkage = .static, .root_module = ffi_mod });
    b.installArtifact(static);

    const unit = b.addTest(.{ .root_module = ffi_mod });

    const integ_mod = b.createModule(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    integ_mod.addImport("dicta_task_ffi", ffi_mod);
    const integ = b.addTest(.{ .root_module = integ_mod });

    const test_step = b.step("test", "Run FFI unit + integration tests");
    test_step.dependOn(&b.addRunArtifact(unit).step);
    test_step.dependOn(&b.addRunArtifact(integ).step);
}
