const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "dkill",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Tests are rooted at src/main.zig which @import's other source files.
    // When adding tests in separate files, import them from main.zig or add
    // dedicated addTest targets here to ensure they are picked up by `zig build test`.
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // Size utility tests
    const size_util_mod = b.createModule(.{
        .root_source_file = b.path("src/utils/size.zig"),
        .target = target,
        .optimize = optimize,
    });

    const size_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/size_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    size_test_mod.addImport("../src/utils/size.zig", size_util_mod);

    const size_tests = b.addTest(.{
        .root_module = size_test_mod,
    });

    const run_size_tests = b.addRunArtifact(size_tests);
    test_step.dependOn(&run_size_tests.step);
}
