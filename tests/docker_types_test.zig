const std = @import("std");
const types = @import("../src/docker/types.zig");

// ─── Container ──────────────────────────────────────────────

test "Container.isRunning returns true when state is running" {
    const c = types.Container{
        .id = "abc123def456",
        .names = &[_][]const u8{"/my-container"},
        .image = "nginx:latest",
        .state = "running",
        .status = "Up 2 hours",
    };
    try std.testing.expect(c.isRunning());
}

test "Container.isRunning returns false when state is exited" {
    const c = types.Container{
        .id = "abc123def456",
        .names = &[_][]const u8{"/my-container"},
        .image = "nginx:latest",
        .state = "exited",
        .status = "Exited (0) 5 minutes ago",
    };
    try std.testing.expect(!c.isRunning());
}

test "Container.isExited returns true when state is exited" {
    const c = types.Container{
        .id = "abc123def456",
        .names = &[_][]const u8{"/my-container"},
        .image = "nginx:latest",
        .state = "exited",
        .status = "Exited (0) 5 minutes ago",
    };
    try std.testing.expect(c.isExited());
}

test "Container.isExited returns false when state is running" {
    const c = types.Container{
        .id = "abc123def456",
        .names = &[_][]const u8{"/my-container"},
        .image = "nginx:latest",
        .state = "running",
        .status = "Up 2 hours",
    };
    try std.testing.expect(!c.isExited());
}

test "Container.shortId returns first 12 characters" {
    const c = types.Container{
        .id = "abc123def456789xyz",
        .names = &[_][]const u8{"/my-container"},
        .image = "nginx:latest",
        .state = "running",
        .status = "Up 2 hours",
    };
    try std.testing.expectEqualStrings("abc123def456", c.shortId());
}

test "Container.shortId returns full id if shorter than 12" {
    const c = types.Container{
        .id = "short",
        .names = &[_][]const u8{"/my-container"},
        .image = "nginx:latest",
        .state = "running",
        .status = "Up 2 hours",
    };
    try std.testing.expectEqualStrings("short", c.shortId());
}

// ─── Image ──────────────────────────────────────────────────

test "Image.isDangling returns true when repo_tags is empty" {
    const img = types.Image{
        .id = "sha256:abc123",
        .repo_tags = &[_][]const u8{},
        .size = 1024,
    };
    try std.testing.expect(img.isDangling());
}

test "Image.isDangling returns true when tag is <none>:<none>" {
    const img = types.Image{
        .id = "sha256:abc123",
        .repo_tags = &[_][]const u8{"<none>:<none>"},
        .size = 1024,
    };
    try std.testing.expect(img.isDangling());
}

test "Image.isDangling returns false when tag exists" {
    const img = types.Image{
        .id = "sha256:abc123",
        .repo_tags = &[_][]const u8{"nginx:latest"},
        .size = 1024,
    };
    try std.testing.expect(!img.isDangling());
}

test "Image.displayTag returns first tag" {
    const img = types.Image{
        .id = "sha256:abc123",
        .repo_tags = &[_][]const u8{ "nginx:latest", "nginx:1.25" },
        .size = 1024,
    };
    try std.testing.expectEqualStrings("nginx:latest", img.displayTag());
}

test "Image.displayTag returns <none>:<none> when repo_tags is empty" {
    const img = types.Image{
        .id = "sha256:abc123",
        .repo_tags = &[_][]const u8{},
        .size = 1024,
    };
    try std.testing.expectEqualStrings("<none>:<none>", img.displayTag());
}

// ─── Volume ─────────────────────────────────────────────────

test "Volume.isOrphaned returns true when not in use" {
    const v = types.Volume{
        .name = "unused-volume",
        .driver = "local",
        .mountpoint = "/var/lib/docker/volumes/unused-volume/_data",
        .in_use = false,
    };
    try std.testing.expect(v.isOrphaned());
}

test "Volume.isOrphaned returns false when in use" {
    const v = types.Volume{
        .name = "active-volume",
        .driver = "local",
        .mountpoint = "/var/lib/docker/volumes/active-volume/_data",
        .in_use = true,
    };
    try std.testing.expect(!v.isOrphaned());
}
