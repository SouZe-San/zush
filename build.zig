const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const iw = b.addModule("zush", .{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    // });

    const vaxis = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    const vaxis_mod = vaxis.module("vaxis");

    // ── Internal library module: "zush" ─────────────────────────────────────
    const zush_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    zush_mod.addImport("vaxis", vaxis_mod);
    zush_mod.linkSystemLibrary("magic", .{});

    // ── Executable module (only main.zig lives here) ────────────────────────
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true, // replace of link library of C
    });

    exe_mod.addImport("vaxis", vaxis_mod);
    exe_mod.addImport("zush", zush_mod);
    // exe_mod.linkSystemLibrary("c", .{});
    // exe_mod.linkSystemLibrary("magic", .{});

    const exe = b.addExecutable(.{
        .name = "zush",
        .root_module = exe_mod,
    });

    exe.use_llvm = true;
    exe.use_lld = true;
    b.installArtifact(exe);

    // const run_step = b.step("run", "Run the app");
    // const run_cmd = b.addRunArtifact(exe);
    // run_cmd.step.dependOn(b.getInstallStep());
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }
    // run_step.dependOn(&run_cmd.step);
    // const mod_tests = b.addTest(.{
    //     .root_module = mod,
    // });
    // const run_mod_tests = b.addRunArtifact(mod_tests);
    // const exe_tests = b.addTest(.{
    //     .root_module = exe.root_module,
    // });
    // const run_exe_tests = b.addRunArtifact(exe_tests);
    // const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_exe_tests.step);
}
