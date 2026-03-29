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
        return std.fmt.bufPrint(buf, "{d} minutes ago", .{minutes}) catch unreachable;
    } else if (diff < 86400) {
        const hours = @divFloor(diff, 3600);
        return std.fmt.bufPrint(buf, "{d} hours ago", .{hours}) catch unreachable;
    } else if (diff < 2592000) {
        const days = @divFloor(diff, 86400);
        return std.fmt.bufPrint(buf, "{d} days ago", .{days}) catch unreachable;
    } else {
        const months = @divFloor(diff, 2592000);
        return std.fmt.bufPrint(buf, "{d} months ago", .{months}) catch unreachable;
    }
}
