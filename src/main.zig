const std = @import("std");
const commands = @import("cli/commands.zig");
const table = @import("cli/table.zig");
const json_output = @import("cli/json_output.zig");
const api = @import("docker/api.zig");

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

test "version string" {
    try std.testing.expectEqualStrings("dkill v0.1.0", versionString());
}
