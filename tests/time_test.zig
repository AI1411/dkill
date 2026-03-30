const std = @import("std");
const time = @import("../src/utils/time.zig");

test "just now" {
    var buf: [32]u8 = undefined;
    const now = std.time.timestamp();
    const ts = now - 30; // 30秒前
    try std.testing.expectEqualStrings("just now", time.relativeTime(ts, &buf));
}

test "1 minute ago (singular)" {
    var buf: [32]u8 = undefined;
    const now = std.time.timestamp();
    const ts = now - 60; // 1分前
    try std.testing.expectEqualStrings("1 minute ago", time.relativeTime(ts, &buf));
}

test "2 minutes ago" {
    var buf: [32]u8 = undefined;
    const now = std.time.timestamp();
    const ts = now - 120; // 2分前
    try std.testing.expectEqualStrings("2 minutes ago", time.relativeTime(ts, &buf));
}

test "3 hours ago" {
    var buf: [32]u8 = undefined;
    const now = std.time.timestamp();
    const ts = now - (3 * 3600); // 3時間前
    try std.testing.expectEqualStrings("3 hours ago", time.relativeTime(ts, &buf));
}

test "5 days ago" {
    var buf: [32]u8 = undefined;
    const now = std.time.timestamp();
    const ts = now - (5 * 86400); // 5日前
    try std.testing.expectEqualStrings("5 days ago", time.relativeTime(ts, &buf));
}

test "2 months ago" {
    var buf: [32]u8 = undefined;
    const now = std.time.timestamp();
    const ts = now - (60 * 86400); // 60日前 = 約2ヶ月
    try std.testing.expectEqualStrings("2 months ago", time.relativeTime(ts, &buf));
}

test "1 year ago (singular)" {
    var buf: [32]u8 = undefined;
    const now = std.time.timestamp();
    const ts = now - (365 * 86400); // 365日前
    try std.testing.expectEqualStrings("1 year ago", time.relativeTime(ts, &buf));
}

test "2 years ago" {
    var buf: [32]u8 = undefined;
    const now = std.time.timestamp();
    const ts = now - (730 * 86400); // 730日前
    try std.testing.expectEqualStrings("2 years ago", time.relativeTime(ts, &buf));
}
