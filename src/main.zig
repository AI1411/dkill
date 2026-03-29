const std = @import("std");

pub const version = "0.1.0";

fn versionString() []const u8 {
    return "dkill v" ++ version;
}

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("{s}\n", .{versionString()});
    try stdout.flush();
}

test "version string" {
    try std.testing.expectEqualStrings("dkill v0.1.0", versionString());
}
