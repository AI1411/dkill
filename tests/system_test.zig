const std = @import("std");
const system = @import("../src/docker/system.zig");
const api = @import("../src/docker/api.zig");

// ─── parseDiskUsage ──────────────────────────────────────────

test "parseDiskUsage parses fixture JSON correctly" {
    const json_str = @embedFile("fixtures/system_df.json");
    const usage = try api.parseDiskUsage(std.testing.allocator, json_str);
    defer api.freeDiskUsage(std.testing.allocator, usage);

    try std.testing.expectEqual(@as(u64, 312456789), usage.LayersSize);
    try std.testing.expectEqual(@as(usize, 1), usage.Containers.len);
    try std.testing.expectEqual(@as(usize, 1), usage.Images.len);
    try std.testing.expectEqual(@as(usize, 1), usage.Volumes.len);
}

test "parseDiskUsage returns error on invalid JSON" {
    // Zig 0.15 JSON parser may return SyntaxError or UnexpectedToken depending on context
    const result = api.parseDiskUsage(std.testing.allocator, "not json");
    try std.testing.expect(result == error.SyntaxError or result == error.UnexpectedToken);
}

// ─── printDiskUsageTable ─────────────────────────────────────

test "printDiskUsageTable outputs correct header" {
    const json_str = @embedFile("fixtures/system_df.json");
    const usage = try api.parseDiskUsage(std.testing.allocator, json_str);
    defer api.freeDiskUsage(std.testing.allocator, usage);

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try system.printDiskUsageTable(fbs.writer(), usage);
    const output = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, output, "TYPE") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "TOTAL") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "ACTIVE") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "RECLAIMABLE") != null);
}

test "printDiskUsageTable outputs Containers row" {
    const json_str = @embedFile("fixtures/system_df.json");
    const usage = try api.parseDiskUsage(std.testing.allocator, json_str);
    defer api.freeDiskUsage(std.testing.allocator, usage);

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try system.printDiskUsageTable(fbs.writer(), usage);
    const output = fbs.getWritten();

    try std.testing.expect(std.mem.indexOf(u8, output, "Containers") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Images") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Volumes") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Build Cache") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Total reclaimable") != null);
}
