const std = @import("std");
const commands = @import("cli/commands.zig");
const table = @import("cli/table.zig");
const json_output = @import("cli/json_output.zig");
const api = @import("docker/api.zig");
const system_display = @import("docker/system.zig");
const tui_app = @import("tui/app.zig");
const tui_input = @import("tui/input.zig");

pub const version = "0.1.0";

const DOCKER_SOCKET = "/var/run/docker.sock";

fn versionString() []const u8 {
    return "dkill v" ++ version;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var stdout_buf: [65536]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file_writer.interface;

    var stderr_buf: [4096]u8 = undefined;
    var stderr_file_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_file_writer.interface;

    const result = commands.parse(args) catch |err| {
        switch (err) {
            error.UnknownCommand => try stderr.print("error: unknown command\n\n", .{}),
            error.UnknownFlag => try stderr.print("error: unknown flag\n\n", .{}),
        }
        try commands.printUsage(stderr);
        try stderr.flush();
        std.process.exit(1);
    };

    switch (result) {
        .help => {
            try stdout.print("{s}\n\n", .{versionString()});
            try commands.printUsage(stdout);
            try stdout.flush();
        },
        .tui => {
            try runTui(allocator, stderr);
        },
        .df => {
            var docker = api.DockerApi.init(allocator, DOCKER_SOCKET);
            const usage = docker.getDiskUsage() catch |err| {
                try stderr.print("error: failed to get disk usage: {s}\n", .{@errorName(err)});
                try stderr.flush();
                std.process.exit(1);
            };
            defer api.freeDiskUsage(allocator, usage);
            try system_display.printDiskUsageTable(stdout, usage);
            try stdout.flush();
        },
        .prune => |opts| {
            try runPrune(allocator, stdout, stderr, opts);
        },
        .containers => |filter| {
            var docker = api.DockerApi.init(allocator, DOCKER_SOCKET);
            const containers = docker.listContainers() catch |err| {
                try stderr.print("error: failed to list containers: {s}\n", .{@errorName(err)});
                try stderr.flush();
                std.process.exit(1);
            };
            defer {
                for (containers) |c| {
                    allocator.free(c.Id);
                    allocator.free(c.Image);
                    allocator.free(c.State);
                    allocator.free(c.Status);
                    for (c.Names) |name| allocator.free(name);
                    allocator.free(c.Names);
                }
                allocator.free(containers);
            }

            var filtered = std.ArrayList(@TypeOf(containers[0])){};
            defer filtered.deinit(allocator);
            for (containers) |c| {
                if (filter.exited and !c.isExited()) continue;
                try filtered.append(allocator, c);
            }

            if (filter.json) {
                try json_output.printContainersJson(stdout, filtered.items);
            } else {
                try table.printContainersDetailed(stdout, filtered.items);
            }
            try stdout.flush();
        },
        .images => |filter| {
            var docker = api.DockerApi.init(allocator, DOCKER_SOCKET);
            const images = docker.listImages() catch |err| {
                try stderr.print("error: failed to list images: {s}\n", .{@errorName(err)});
                try stderr.flush();
                std.process.exit(1);
            };
            defer {
                for (images) |img| {
                    allocator.free(img.Id);
                    for (img.RepoTags) |tag| allocator.free(tag);
                    allocator.free(img.RepoTags);
                }
                allocator.free(images);
            }

            var filtered = std.ArrayList(@TypeOf(images[0])){};
            defer filtered.deinit(allocator);
            for (images) |img| {
                if (filter.dangling and !img.isDangling()) continue;
                try filtered.append(allocator, img);
            }

            if (filter.json) {
                try json_output.printImagesJson(stdout, filtered.items);
            } else {
                try table.printImages(stdout, filtered.items);
            }
            try stdout.flush();
        },
        .volumes => |filter| {
            var docker = api.DockerApi.init(allocator, DOCKER_SOCKET);
            const volumes = docker.listVolumes() catch |err| {
                try stderr.print("error: failed to list volumes: {s}\n", .{@errorName(err)});
                try stderr.flush();
                std.process.exit(1);
            };
            defer {
                for (volumes) |v| {
                    allocator.free(v.Name);
                    allocator.free(v.Driver);
                    allocator.free(v.Mountpoint);
                }
                allocator.free(volumes);
            }

            var filtered = std.ArrayList(@TypeOf(volumes[0])){};
            defer filtered.deinit(allocator);
            for (volumes) |v| {
                if (filter.orphaned and !v.isOrphaned()) continue;
                try filtered.append(allocator, v);
            }

            if (filter.json) {
                try json_output.printVolumesJson(stdout, filtered.items);
            } else {
                try table.printVolumes(stdout, filtered.items);
            }
            try stdout.flush();
        },
    }
}

/// TUI モードを起動する。
fn runTui(allocator: std.mem.Allocator, stderr: anytype) !void {
    var app = tui_app.App.init(allocator, DOCKER_SOCKET);
    defer app.deinit();

    app.loadData() catch |err| {
        try stderr.print("error: failed to load Docker data: {s}\n", .{@errorName(err)});
        try stderr.flush();
        std.process.exit(1);
    };

    const stdin_file = std.fs.File.stdin();
    const raw = tui_input.RawMode.enable() catch |err| {
        try stderr.print("error: failed to enable raw mode: {s}\n", .{@errorName(err)});
        try stderr.flush();
        std.process.exit(1);
    };
    defer raw.disable();

    // カーソル非表示
    const stdout_file = std.fs.File.stdout();
    _ = stdout_file.write("\x1b[?25l") catch {};

    _ = stdin_file;

    while (true) {
        try app.draw();

        const key = tui_input.readKeyFromStdin() catch break;
        app.handleKey(key);

        if (app.shouldQuit()) break;

        if (app.mode == .deleting) {
            runDelete(allocator, &app, stderr) catch {};
            app.loadData() catch {};
        }
    }

    // カーソル表示復元 + 画面クリア
    _ = stdout_file.write("\x1b[?25h") catch {};
    _ = stdout_file.write("\x1b[2J\x1b[H") catch {};
}

/// 選択されたリソースを削除する。
fn runDelete(allocator: std.mem.Allocator, app: *tui_app.App, stderr: anytype) !void {
    var docker = api.DockerApi.init(allocator, DOCKER_SOCKET);
    const list = app.currentList();

    for (list.items) |item| {
        if (!item.selected) continue;
        const del_err = switch (app.current_tab) {
            .containers => docker.removeContainer(item.id),
            .images => docker.removeImage(item.id),
            .volumes => docker.removeVolume(item.id),
        };
        del_err catch |e| {
            try stderr.print("warning: failed to delete {s}: {s}\n", .{ item.id, @errorName(e) });
            try stderr.flush();
        };
    }
    app.mode = .normal;
}

/// prune サブコマンドを実行する。
fn runPrune(
    allocator: std.mem.Allocator,
    stdout: anytype,
    stderr: anytype,
    opts: commands.PruneOptions,
) !void {
    var docker = api.DockerApi.init(allocator, DOCKER_SOCKET);

    const do_containers = opts.containers or opts.all;
    const do_images = opts.images_dangling or opts.all;
    const do_volumes = opts.volumes_orphaned or opts.all;

    var target_containers = std.ArrayList([]const u8){};
    defer {
        for (target_containers.items) |id| allocator.free(id);
        target_containers.deinit(allocator);
    }

    var target_images = std.ArrayList([]const u8){};
    defer {
        for (target_images.items) |id| allocator.free(id);
        target_images.deinit(allocator);
    }

    var target_volumes = std.ArrayList([]const u8){};
    defer {
        for (target_volumes.items) |name| allocator.free(name);
        target_volumes.deinit(allocator);
    }

    if (do_containers) {
        const containers = docker.listContainers() catch |err| {
            try stderr.print("error: failed to list containers: {s}\n", .{@errorName(err)});
            try stderr.flush();
            std.process.exit(1);
        };
        defer {
            for (containers) |c| {
                allocator.free(c.Id);
                allocator.free(c.Image);
                allocator.free(c.State);
                allocator.free(c.Status);
                for (c.Names) |name| allocator.free(name);
                allocator.free(c.Names);
            }
            allocator.free(containers);
        }
        for (containers) |c| {
            if (c.isExited()) {
                try target_containers.append(allocator, try allocator.dupe(u8, c.Id));
            }
        }
    }

    if (do_images) {
        const images = docker.listImages() catch |err| {
            try stderr.print("error: failed to list images: {s}\n", .{@errorName(err)});
            try stderr.flush();
            std.process.exit(1);
        };
        defer {
            for (images) |img| {
                allocator.free(img.Id);
                for (img.RepoTags) |tag| allocator.free(tag);
                allocator.free(img.RepoTags);
            }
            allocator.free(images);
        }
        for (images) |img| {
            if (img.isDangling()) {
                try target_images.append(allocator, try allocator.dupe(u8, img.Id));
            }
        }
    }

    if (do_volumes) {
        const volumes = docker.listVolumes() catch |err| {
            try stderr.print("error: failed to list volumes: {s}\n", .{@errorName(err)});
            try stderr.flush();
            std.process.exit(1);
        };
        defer {
            for (volumes) |v| {
                allocator.free(v.Name);
                allocator.free(v.Driver);
                allocator.free(v.Mountpoint);
            }
            allocator.free(volumes);
        }
        for (volumes) |v| {
            if (v.isOrphaned()) {
                try target_volumes.append(allocator, try allocator.dupe(u8, v.Name));
            }
        }
    }

    // 削除予定を表示
    try stdout.print("Resources to be removed:\n", .{});
    for (target_containers.items) |id| {
        try stdout.print("  container: {s}\n", .{id[0..@min(id.len, 12)]});
    }
    for (target_images.items) |id| {
        try stdout.print("  image:     {s}\n", .{id[0..@min(id.len, 12)]});
    }
    for (target_volumes.items) |name| {
        try stdout.print("  volume:    {s}\n", .{name});
    }

    const total = target_containers.items.len + target_images.items.len + target_volumes.items.len;
    if (total == 0) {
        try stdout.print("Nothing to remove.\n", .{});
        try stdout.flush();
        return;
    }

    if (opts.dry_run) {
        try stdout.print("\nDry run: no changes made.\n", .{});
        try stdout.flush();
        return;
    }

    if (!opts.yes) {
        try stdout.print("\nProceed? [y/N] ", .{});
        try stdout.flush();
        var line_buf: [16]u8 = undefined;
        const stdin_file = std.fs.File.stdin();
        const n = stdin_file.read(&line_buf) catch 0;
        if (n == 0 or (line_buf[0] != 'y' and line_buf[0] != 'Y')) {
            try stdout.print("Aborted.\n", .{});
            try stdout.flush();
            return;
        }
    }

    // 削除実行
    for (target_containers.items) |id| {
        docker.removeContainer(id) catch |err| {
            try stderr.print("warning: failed to remove container {s}: {s}\n", .{ id[0..@min(id.len, 12)], @errorName(err) });
            try stderr.flush();
        };
    }
    for (target_images.items) |id| {
        docker.removeImage(id) catch |err| {
            try stderr.print("warning: failed to remove image {s}: {s}\n", .{ id[0..@min(id.len, 12)], @errorName(err) });
            try stderr.flush();
        };
    }
    for (target_volumes.items) |name| {
        docker.removeVolume(name) catch |err| {
            try stderr.print("warning: failed to remove volume {s}: {s}\n", .{ name, @errorName(err) });
            try stderr.flush();
        };
    }

    try stdout.print("Done.\n", .{});
    try stdout.flush();
}

test "version string" {
    try std.testing.expectEqualStrings("dkill v0.1.0", versionString());
}
