const std = @import("std");
const size = @import("../src/utils/size.zig");

test "0 bytes" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("0 B", size.humanReadable(0, &buf));
}

test "999 bytes" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("999 B", size.humanReadable(999, &buf));
}

test "1024 bytes = 1.0 KB" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("1.0 KB", size.humanReadable(1024, &buf));
}

test "1572864 bytes = 1.5 MB" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("1.5 MB", size.humanReadable(1572864, &buf));
}

test "2576980377 bytes = 2.4 GB" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("2.4 GB", size.humanReadable(2576980377, &buf));
}

// 境界値回帰テスト: 単位直前の値が上位単位で表示されないことを確認
test "1048575 bytes (1MB-1) should not display as 1024.0 KB" {
    var buf: [32]u8 = undefined;
    const result = size.humanReadable(1048575, &buf);
    try std.testing.expect(!std.mem.eql(u8, "1024.0 KB", result));
    // 正しくは 1023.9 KB か 1.0 MB のどちらか（1024.0 KB は不正）
    const is_valid = std.mem.eql(u8, "1023.9 KB", result) or std.mem.eql(u8, "1.0 MB", result);
    try std.testing.expect(is_valid);
}

test "1073741823 bytes (1GB-1) should not display as 1024.0 MB" {
    var buf: [32]u8 = undefined;
    const result = size.humanReadable(1073741823, &buf);
    try std.testing.expect(!std.mem.eql(u8, "1024.0 MB", result));
    const is_valid = std.mem.eql(u8, "1023.9 MB", result) or std.mem.eql(u8, "1.0 GB", result);
    try std.testing.expect(is_valid);
}
