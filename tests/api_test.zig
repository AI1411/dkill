const std = @import("std");
const api = @import("../src/docker/api.zig");

// ─── parseContainers ────────────────────────────────────────

test "parseContainers parses fixture JSON correctly" {
    const json_str = @embedFile("fixtures/containers.json");
    const containers = try api.parseContainers(std.testing.allocator, json_str);
    defer {
        for (containers) |c| {
            std.testing.allocator.free(c.Id);
            std.testing.allocator.free(c.Image);
            std.testing.allocator.free(c.State);
            std.testing.allocator.free(c.Status);
            for (c.Names) |name| std.testing.allocator.free(name);
            std.testing.allocator.free(c.Names);
        }
        std.testing.allocator.free(containers);
    }

    try std.testing.expectEqual(@as(usize, 2), containers.len);
    try std.testing.expectEqualStrings("running", containers[0].State);
    try std.testing.expectEqualStrings("exited", containers[1].State);
}

test "parseContainers returns error on invalid JSON" {
    try std.testing.expectError(
        error.UnexpectedToken,
        api.parseContainers(std.testing.allocator, "not json"),
    );
}

// ─── parseImages ────────────────────────────────────────────

test "parseImages parses fixture JSON correctly" {
    const json_str = @embedFile("fixtures/images.json");
    const images = try api.parseImages(std.testing.allocator, json_str);
    defer {
        for (images) |img| {
            std.testing.allocator.free(img.Id);
            for (img.RepoTags) |tag| std.testing.allocator.free(tag);
            std.testing.allocator.free(img.RepoTags);
        }
        std.testing.allocator.free(images);
    }

    try std.testing.expectEqual(@as(usize, 3), images.len);
    try std.testing.expect(!images[0].isDangling()); // nginx:latest
    try std.testing.expect(images[1].isDangling()); // <none>:<none>
    try std.testing.expect(images[2].isDangling()); // empty tags
}

test "parseImages returns error on invalid JSON" {
    try std.testing.expectError(
        error.UnexpectedToken,
        api.parseImages(std.testing.allocator, "not json"),
    );
}

// ─── parseVolumes ────────────────────────────────────────────

test "parseVolumes parses fixture JSON correctly" {
    const json_str = @embedFile("fixtures/volumes.json");
    const volumes = try api.parseVolumes(std.testing.allocator, json_str);
    defer {
        for (volumes) |v| {
            std.testing.allocator.free(v.Name);
            std.testing.allocator.free(v.Driver);
            std.testing.allocator.free(v.Mountpoint);
        }
        std.testing.allocator.free(volumes);
    }

    try std.testing.expectEqual(@as(usize, 2), volumes.len);
    try std.testing.expectEqualStrings("active-volume", volumes[0].Name);
    try std.testing.expect(!volumes[0].isOrphaned());
    try std.testing.expectEqualStrings("unused-volume", volumes[1].Name);
    try std.testing.expect(volumes[1].isOrphaned());
}

test "parseVolumes returns error on invalid JSON" {
    try std.testing.expectError(
        error.SyntaxError,
        api.parseVolumes(std.testing.allocator, "not json"),
    );
}
