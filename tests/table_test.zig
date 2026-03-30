const std = @import("std");
const table = @import("../src/cli/table.zig");
const types = @import("../src/docker/types.zig");

test "printContainersDetailed outputs header and rows" {
    const names1 = [_][]const u8{"/mycontainer"};
    const containers = [_]types.Container{
        .{
            .Id = "abc123def456789",
            .Names = &names1,
            .Image = "nginx:latest",
            .State = "running",
            .Status = "Up 2 hours",
        },
    };

    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try table.printContainersDetailed(fbs.writer(), &containers);
    const written = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, written, "CONTAINER ID") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "abc123def456") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "nginx:latest") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "running") != null);
}

test "printImages outputs header and rows" {
    const tags = [_][]const u8{"nginx:latest"};
    const images = [_]types.Image{
        .{
            .Id = "sha256:abc123def456789",
            .RepoTags = &tags,
            .Size = 1024 * 1024 * 50,
        },
    };

    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try table.printImages(fbs.writer(), &images);
    const written = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, written, "IMAGE ID") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "nginx:latest") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "MB") != null);
}

test "printVolumes outputs header and rows" {
    const volumes = [_]types.Volume{
        .{
            .Name = "myvolume",
            .Driver = "local",
            .Mountpoint = "/var/lib/docker/volumes/myvolume/_data",
            .UsageData = null,
        },
    };

    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try table.printVolumes(fbs.writer(), &volumes);
    const written = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, written, "VOLUME NAME") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "myvolume") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "local") != null);
}

test "printContainersDetailed empty list outputs only header" {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try table.printContainersDetailed(fbs.writer(), &.{});
    const written = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, written, "CONTAINER ID") != null);
}
