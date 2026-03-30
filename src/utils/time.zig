const std = @import("std");

/// Unix timestamp を相対時間文字列に変換する。
/// 例: (now - 5日) → "5 days ago"
///
/// buf は最低 32 バイト必要。
pub fn relativeTime(unix_ts: i64, buf: []u8) []const u8 {
    std.debug.assert(buf.len >= 32);

    const now = std.time.timestamp();
    const diff = now - unix_ts;

    if (diff < 60) {
        return "just now";
    } else if (diff < 3600) {
        const minutes = @divFloor(diff, 60);
        const s: []const u8 = if (minutes == 1) "" else "s";
        return std.fmt.bufPrint(buf, "{d} minute{s} ago", .{ minutes, s }) catch unreachable;
    } else if (diff < 86400) {
        const hours = @divFloor(diff, 3600);
        const s: []const u8 = if (hours == 1) "" else "s";
        return std.fmt.bufPrint(buf, "{d} hour{s} ago", .{ hours, s }) catch unreachable;
    } else if (diff < 2592000) {
        const days = @divFloor(diff, 86400);
        const s: []const u8 = if (days == 1) "" else "s";
        return std.fmt.bufPrint(buf, "{d} day{s} ago", .{ days, s }) catch unreachable;
    } else if (diff < 31536000) {
        const months = @divFloor(diff, 2592000);
        const s: []const u8 = if (months == 1) "" else "s";
        return std.fmt.bufPrint(buf, "{d} month{s} ago", .{ months, s }) catch unreachable;
    } else {
        const years = @divFloor(diff, 31536000);
        const s: []const u8 = if (years == 1) "" else "s";
        return std.fmt.bufPrint(buf, "{d} year{s} ago", .{ years, s }) catch unreachable;
    }
}
