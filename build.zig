const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─── モジュール定義 ───────────────────────────────────────
    const docker_types_mod = b.createModule(.{
        .root_source_file = b.path("src/docker/types.zig"),
        .target = target,
        .optimize = optimize,
    });

    const docker_client_mod = b.createModule(.{
        .root_source_file = b.path("src/docker/client.zig"),
        .target = target,
        .optimize = optimize,
    });

    const docker_api_mod = b.createModule(.{
        .root_source_file = b.path("src/docker/api.zig"),
        .target = target,
        .optimize = optimize,
    });
    docker_api_mod.addImport("client.zig", docker_client_mod);
    docker_api_mod.addImport("types.zig", docker_types_mod);

    const size_util_mod = b.createModule(.{
        .root_source_file = b.path("src/utils/size.zig"),
        .target = target,
        .optimize = optimize,
    });

    const time_util_mod = b.createModule(.{
        .root_source_file = b.path("src/utils/time.zig"),
        .target = target,
        .optimize = optimize,
    });

    const system_mod = b.createModule(.{
        .root_source_file = b.path("src/docker/system.zig"),
        .target = target,
        .optimize = optimize,
    });
    system_mod.addImport("types.zig", docker_types_mod);
    system_mod.addImport("../utils/size.zig", size_util_mod);

    const tui_input_mod = b.createModule(.{
        .root_source_file = b.path("src/tui/input.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tui_render_mod = b.createModule(.{
        .root_source_file = b.path("src/tui/render.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tui_list_mod = b.createModule(.{
        .root_source_file = b.path("src/tui/list.zig"),
        .target = target,
        .optimize = optimize,
    });
    tui_list_mod.addImport("render.zig", tui_render_mod);

    const tui_app_mod = b.createModule(.{
        .root_source_file = b.path("src/tui/app.zig"),
        .target = target,
        .optimize = optimize,
    });
    tui_app_mod.addImport("../docker/api.zig", docker_api_mod);
    tui_app_mod.addImport("../docker/types.zig", docker_types_mod);
    tui_app_mod.addImport("../utils/size.zig", size_util_mod);
    tui_app_mod.addImport("list.zig", tui_list_mod);
    tui_app_mod.addImport("render.zig", tui_render_mod);
    tui_app_mod.addImport("input.zig", tui_input_mod);

    // ─── 実行ファイル ─────────────────────────────────────────
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("cli/commands.zig", b.createModule(.{
        .root_source_file = b.path("src/cli/commands.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const cli_table_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/table.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_table_mod.addImport("../docker/types.zig", docker_types_mod);
    cli_table_mod.addImport("../utils/size.zig", size_util_mod);

    const cli_json_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/json_output.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_json_mod.addImport("../docker/types.zig", docker_types_mod);

    const exe = b.addExecutable(.{
        .name = "dkill",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("cli/commands.zig", b.createModule(.{
        .root_source_file = b.path("src/cli/commands.zig"),
        .target = target,
        .optimize = optimize,
    }));
    exe.root_module.addImport("cli/table.zig", cli_table_mod);
    exe.root_module.addImport("cli/json_output.zig", cli_json_mod);
    exe.root_module.addImport("docker/api.zig", docker_api_mod);
    exe.root_module.addImport("docker/system.zig", system_mod);
    exe.root_module.addImport("tui/app.zig", tui_app_mod);
    exe.root_module.addImport("tui/input.zig", tui_input_mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // ─── テストステップ ───────────────────────────────────────
    const test_step = b.step("test", "Run unit tests");

    // main.zig tests
    const main_test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_test_mod.addImport("cli/commands.zig", b.createModule(.{
        .root_source_file = b.path("src/cli/commands.zig"),
        .target = target,
        .optimize = optimize,
    }));
    main_test_mod.addImport("cli/table.zig", cli_table_mod);
    main_test_mod.addImport("cli/json_output.zig", cli_json_mod);
    main_test_mod.addImport("docker/api.zig", docker_api_mod);
    main_test_mod.addImport("docker/system.zig", system_mod);
    main_test_mod.addImport("tui/app.zig", tui_app_mod);
    main_test_mod.addImport("tui/input.zig", tui_input_mod);
    const main_tests = b.addTest(.{ .root_module = main_test_mod });
    test_step.dependOn(&b.addRunArtifact(main_tests).step);

    // Size utility tests
    const size_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/size_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    size_test_mod.addImport("../src/utils/size.zig", size_util_mod);
    const size_tests = b.addTest(.{ .root_module = size_test_mod });
    test_step.dependOn(&b.addRunArtifact(size_tests).step);

    // Time utility tests
    const time_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/time_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    time_test_mod.addImport("../src/utils/time.zig", time_util_mod);
    const time_tests = b.addTest(.{ .root_module = time_test_mod });
    test_step.dependOn(&b.addRunArtifact(time_tests).step);

    // Docker types tests
    const docker_types_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/docker_types_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    docker_types_test_mod.addImport("../src/docker/types.zig", docker_types_mod);
    const docker_types_tests = b.addTest(.{ .root_module = docker_types_test_mod });
    test_step.dependOn(&b.addRunArtifact(docker_types_tests).step);

    // Docker client tests
    const docker_client_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/client_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    docker_client_test_mod.addImport("../src/docker/client.zig", docker_client_mod);
    const docker_client_tests = b.addTest(.{ .root_module = docker_client_test_mod });
    test_step.dependOn(&b.addRunArtifact(docker_client_tests).step);

    // Docker API tests
    const docker_api_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/api_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    docker_api_test_mod.addImport("../src/docker/api.zig", docker_api_mod);
    const docker_api_tests = b.addTest(.{ .root_module = docker_api_test_mod });
    test_step.dependOn(&b.addRunArtifact(docker_api_tests).step);

    // System tests
    const system_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/system_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    system_test_mod.addImport("../src/docker/system.zig", system_mod);
    system_test_mod.addImport("../src/docker/api.zig", docker_api_mod);
    const system_tests = b.addTest(.{ .root_module = system_test_mod });
    test_step.dependOn(&b.addRunArtifact(system_tests).step);

    // CLI commands tests
    const cli_commands_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/commands.zig"),
        .target = target,
        .optimize = optimize,
    });
    const cli_commands_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/commands_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_commands_test_mod.addImport("../src/cli/commands.zig", cli_commands_mod);
    const cli_commands_tests = b.addTest(.{ .root_module = cli_commands_test_mod });
    test_step.dependOn(&b.addRunArtifact(cli_commands_tests).step);

    // CLI table tests
    const cli_table_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/table_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_table_test_mod.addImport("../src/cli/table.zig", cli_table_mod);
    cli_table_test_mod.addImport("../src/docker/types.zig", docker_types_mod);
    const cli_table_tests = b.addTest(.{ .root_module = cli_table_test_mod });
    test_step.dependOn(&b.addRunArtifact(cli_table_tests).step);

    // CLI json_output tests
    const cli_json_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/json_output_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_json_test_mod.addImport("../src/cli/json_output.zig", cli_json_mod);
    cli_json_test_mod.addImport("../src/docker/types.zig", docker_types_mod);
    const cli_json_tests = b.addTest(.{ .root_module = cli_json_test_mod });
    test_step.dependOn(&b.addRunArtifact(cli_json_tests).step);

    // TUI input tests
    const tui_input_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/input_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tui_input_test_mod.addImport("../src/tui/input.zig", tui_input_mod);
    const tui_input_tests = b.addTest(.{ .root_module = tui_input_test_mod });
    test_step.dependOn(&b.addRunArtifact(tui_input_tests).step);

    // TUI render tests
    const tui_render_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/render_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tui_render_test_mod.addImport("../src/tui/render.zig", tui_render_mod);
    const tui_render_tests = b.addTest(.{ .root_module = tui_render_test_mod });
    test_step.dependOn(&b.addRunArtifact(tui_render_tests).step);

    // TUI list tests
    const tui_list_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/list_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tui_list_test_mod.addImport("../src/tui/list.zig", tui_list_mod);
    const tui_list_tests = b.addTest(.{ .root_module = tui_list_test_mod });
    test_step.dependOn(&b.addRunArtifact(tui_list_tests).step);
}
