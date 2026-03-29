const std = @import("std");

/// バイト数を人間が読みやすい形式に変換する。
/// 例: 1572864 → "1.5 MB"
pub fn humanReadable(bytes: u64, buf: []u8) []const u8 {
    const kb: u64 = 1024;
    const mb: u64 = 1024 * kb;
    const gb: u64 = 1024 * mb;

    if (bytes < kb) {
        return std.fmt.bufPrint(buf, "{d} B", .{bytes}) catch unreachable;
    } else if (bytes < mb) {
        const value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(kb));
        return std.fmt.bufPrint(buf, "{d:.1} KB", .{value}) catch unreachable;
    } else if (bytes < gb) {
        const value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(mb));
        return std.fmt.bufPrint(buf, "{d:.1} MB", .{value}) catch unreachable;
    } else {
        const value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(gb));
        return std.fmt.bufPrint(buf, "{d:.1} GB", .{value}) catch unreachable;
    }
}

test "0 bytes" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("0 B", humanReadable(0, &buf));
}

test "999 bytes" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("999 B", humanReadable(999, &buf));
}

test "1024 bytes = 1.0 KB" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("1.0 KB", humanReadable(1024, &buf));
}

test "1572864 bytes = 1.5 MB" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("1.5 MB", humanReadable(1572864, &buf));
}

test "2576980377 bytes = 2.4 GB" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("2.4 GB", humanReadable(2576980377, &buf));
}
