const std = @import("std");
const size = @import("../src/utils/size.zig");

test "0 bytes" {
    var buf: [32]u8 = undefined;
    const result = size.humanReadable(0, &buf);
    try std.testing.expectEqualStrings("0 B", result);
}

test "999 bytes" {
    var buf: [32]u8 = undefined;
    const result = size.humanReadable(999, &buf);
    try std.testing.expectEqualStrings("999 B", result);
}

test "1024 bytes = 1.0 KB" {
    var buf: [32]u8 = undefined;
    const result = size.humanReadable(1024, &buf);
    try std.testing.expectEqualStrings("1.0 KB", result);
}

test "1572864 bytes = 1.5 MB" {
    var buf: [32]u8 = undefined;
    const result = size.humanReadable(1572864, &buf);
    try std.testing.expectEqualStrings("1.5 MB", result);
}

test "2576980377 bytes = 2.4 GB" {
    var buf: [32]u8 = undefined;
    const result = size.humanReadable(2576980377, &buf);
    try std.testing.expectEqualStrings("2.4 GB", result);
}
