const std = @import("std");
const types = @import("../src/docker/types.zig");

// ─── Container ──────────────────────────────────────────────

test "Container.isRunning returns true when state is running" {
    const c = types.Container{
        .Id = "abc123def456",
        .Names = &[_][]const u8{"/my-container"},
        .Image = "nginx:latest",
        .State = "running",
        .Status = "Up 2 hours",
    };
    try std.testing.expect(c.isRunning());
}

test "Container.isRunning returns false when state is exited" {
    const c = types.Container{
        .Id = "abc123def456",
        .Names = &[_][]const u8{"/my-container"},
        .Image = "nginx:latest",
        .State = "exited",
        .Status = "Exited (0) 5 minutes ago",
    };
    try std.testing.expect(!c.isRunning());
}

test "Container.isExited returns true when state is exited" {
    const c = types.Container{
        .Id = "abc123def456",
        .Names = &[_][]const u8{"/my-container"},
        .Image = "nginx:latest",
        .State = "exited",
        .Status = "Exited (0) 5 minutes ago",
    };
    try std.testing.expect(c.isExited());
}

test "Container.isExited returns false when state is running" {
    const c = types.Container{
        .Id = "abc123def456",
        .Names = &[_][]const u8{"/my-container"},
        .Image = "nginx:latest",
        .State = "running",
        .Status = "Up 2 hours",
    };
    try std.testing.expect(!c.isExited());
}

test "Container.shortId returns first 12 characters" {
    const c = types.Container{
        .Id = "abc123def456789xyz",
        .Names = &[_][]const u8{"/my-container"},
        .Image = "nginx:latest",
        .State = "running",
        .Status = "Up 2 hours",
    };
    try std.testing.expectEqualStrings("abc123def456", c.shortId());
}

test "Container.shortId returns full id if shorter than 12" {
    const c = types.Container{
        .Id = "short",
        .Names = &[_][]const u8{"/my-container"},
        .Image = "nginx:latest",
        .State = "running",
        .Status = "Up 2 hours",
    };
    try std.testing.expectEqualStrings("short", c.shortId());
}

// ─── Image ──────────────────────────────────────────────────

test "Image.isDangling returns true when RepoTags is empty" {
    const img = types.Image{
        .Id = "sha256:abc123",
        .RepoTags = &[_][]const u8{},
        .Size = 1024,
    };
    try std.testing.expect(img.isDangling());
}

test "Image.isDangling returns true when tag is <none>:<none>" {
    const img = types.Image{
        .Id = "sha256:abc123",
        .RepoTags = &[_][]const u8{"<none>:<none>"},
        .Size = 1024,
    };
    try std.testing.expect(img.isDangling());
}

test "Image.isDangling returns false when tag exists" {
    const img = types.Image{
        .Id = "sha256:abc123",
        .RepoTags = &[_][]const u8{"nginx:latest"},
        .Size = 1024,
    };
    try std.testing.expect(!img.isDangling());
}

test "Image.displayTag returns first tag" {
    const img = types.Image{
        .Id = "sha256:abc123",
        .RepoTags = &[_][]const u8{ "nginx:latest", "nginx:1.25" },
        .Size = 1024,
    };
    try std.testing.expectEqualStrings("nginx:latest", img.displayTag());
}

test "Image.displayTag returns <none>:<none> when RepoTags is empty" {
    const img = types.Image{
        .Id = "sha256:abc123",
        .RepoTags = &[_][]const u8{},
        .Size = 1024,
    };
    try std.testing.expectEqualStrings("<none>:<none>", img.displayTag());
}

// ─── Volume ─────────────────────────────────────────────────

test "Volume.isOrphaned returns true when RefCount is 0" {
    const v = types.Volume{
        .Name = "unused-volume",
        .Driver = "local",
        .Mountpoint = "/var/lib/docker/volumes/unused-volume/_data",
        .UsageData = .{ .RefCount = 0, .Size = 0 },
    };
    try std.testing.expect(v.isOrphaned());
}

test "Volume.isOrphaned returns false when RefCount is positive" {
    const v = types.Volume{
        .Name = "active-volume",
        .Driver = "local",
        .Mountpoint = "/var/lib/docker/volumes/active-volume/_data",
        .UsageData = .{ .RefCount = 1, .Size = 10240 },
    };
    try std.testing.expect(!v.isOrphaned());
}

test "Volume.isOrphaned returns true when UsageData is null" {
    const v = types.Volume{
        .Name = "unknown-volume",
        .Driver = "local",
        .Mountpoint = "/var/lib/docker/volumes/unknown-volume/_data",
        .UsageData = null,
    };
    try std.testing.expect(v.isOrphaned());
}

// ─── Fixture JSON パーステスト ───────────────────────────────

test "parse containers from JSON fixture" {
    const json_str = @embedFile("fixtures/containers.json");
    const parsed = try std.json.parseFromSlice([]types.Container, std.testing.allocator, json_str, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2), parsed.value.len);
    try std.testing.expectEqualStrings("running", parsed.value[0].State);
    try std.testing.expectEqualStrings("exited", parsed.value[1].State);
}

test "parse images from JSON fixture" {
    const json_str = @embedFile("fixtures/images.json");
    const parsed = try std.json.parseFromSlice([]types.Image, std.testing.allocator, json_str, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 3), parsed.value.len);
    try std.testing.expect(!parsed.value[0].isDangling()); // nginx:latest
    try std.testing.expect(parsed.value[1].isDangling()); // <none>:<none>
    try std.testing.expect(parsed.value[2].isDangling()); // empty tags
}
