const std = @import("std");
const json_output = @import("../src/cli/json_output.zig");
const types = @import("../src/docker/types.zig");

test "printContainersJson outputs valid JSON structure" {
    const names1 = [_][]const u8{"/mycontainer"};
    const containers = [_]types.Container{
        .{
            .Id = "abc123",
            .Names = &names1,
            .Image = "nginx:latest",
            .State = "running",
            .Status = "Up 2 hours",
        },
    };

    var buf: [2048]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try json_output.printContainersJson(fbs.writer(), &containers);
    const written = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, written, "\"id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "abc123") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "\"image\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "nginx:latest") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "\"state\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "running") != null);
    // JSON 配列として開始・終了
    try std.testing.expect(written[0] == '[');
    try std.testing.expect(written[written.len - 2] == ']' or written[written.len - 1] == ']');
}

test "printContainersJson empty list outputs empty array" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try json_output.printContainersJson(fbs.writer(), &.{});
    const written = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, written, "[") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "]") != null);
}

test "printImagesJson outputs valid JSON structure" {
    const tags = [_][]const u8{"nginx:latest"};
    const images = [_]types.Image{
        .{
            .Id = "sha256:abc",
            .RepoTags = &tags,
            .Size = 1024,
        },
    };

    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try json_output.printImagesJson(fbs.writer(), &images);
    const written = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, written, "\"id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "\"repoTags\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "\"size\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "1024") != null);
}

test "printVolumesJson outputs valid JSON structure" {
    const volumes = [_]types.Volume{
        .{
            .Name = "myvolume",
            .Driver = "local",
            .Mountpoint = "/data",
            .UsageData = .{ .RefCount = 2, .Size = 512 },
        },
    };

    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try json_output.printVolumesJson(fbs.writer(), &volumes);
    const written = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, written, "\"name\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "myvolume") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "\"usageData\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "\"refCount\"") != null);
}

test "printVolumesJson null UsageData omits usageData field" {
    const volumes = [_]types.Volume{
        .{
            .Name = "orphan",
            .Driver = "local",
            .Mountpoint = "/data",
            .UsageData = null,
        },
    };

    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try json_output.printVolumesJson(fbs.writer(), &volumes);
    const written = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, written, "usageData") == null);
}
