const std = @import("std");

/// バイト数を人間が読みやすい形式に変換する。
/// 例: 1572864 → "1.5 MB"
///
/// buf は最低 16 バイト必要。
pub fn humanReadable(bytes: u64, buf: []u8) []const u8 {
    std.debug.assert(buf.len >= 16);

    const kb: u64 = 1024;
    const mb: u64 = 1024 * kb;
    const gb: u64 = 1024 * mb;

    if (bytes < kb) {
        return std.fmt.bufPrint(buf, "{d} B", .{bytes}) catch unreachable;
    } else if (bytes < mb) {
        const value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(kb));
        if (value >= 1023.95) {
            const mb_value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(mb));
            return std.fmt.bufPrint(buf, "{d:.1} MB", .{mb_value}) catch unreachable;
        }
        return std.fmt.bufPrint(buf, "{d:.1} KB", .{value}) catch unreachable;
    } else if (bytes < gb) {
        const value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(mb));
        if (value >= 1023.95) {
            const gb_value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(gb));
            return std.fmt.bufPrint(buf, "{d:.1} GB", .{gb_value}) catch unreachable;
        }
        return std.fmt.bufPrint(buf, "{d:.1} MB", .{value}) catch unreachable;
    } else {
        const value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(gb));
        return std.fmt.bufPrint(buf, "{d:.1} GB", .{value}) catch unreachable;
    }
}
