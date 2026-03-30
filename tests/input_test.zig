const std = @import("std");
const input = @import("../src/tui/input.zig");

// ─── readKey: 基本文字 ───────────────────────────────────────

test "readKey returns char for printable character" {
    var buf = [_]u8{'j'};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .char);
    try std.testing.expectEqual(@as(u8, 'j'), key.char);
}

test "readKey returns enter for 0x0d" {
    var buf = [_]u8{0x0d};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .enter);
}

test "readKey returns enter for 0x0a" {
    var buf = [_]u8{0x0a};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .enter);
}

test "readKey returns space for 0x20" {
    var buf = [_]u8{' '};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .space);
}

test "readKey returns tab for 0x09" {
    var buf = [_]u8{0x09};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .tab);
}

test "readKey returns backspace for 0x7f" {
    var buf = [_]u8{0x7f};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .backspace);
}

test "readKey returns ctrl_c for 0x03" {
    var buf = [_]u8{0x03};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .ctrl_c);
}

test "readKey returns ctrl_d for 0x04" {
    var buf = [_]u8{0x04};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .ctrl_d);
}

// ─── readKey: エスケープシーケンス ──────────────────────────

test "readKey returns arrow_up for ESC [ A" {
    var buf = [_]u8{ 0x1b, '[', 'A' };
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .arrow_up);
}

test "readKey returns arrow_down for ESC [ B" {
    var buf = [_]u8{ 0x1b, '[', 'B' };
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .arrow_down);
}

test "readKey returns arrow_right for ESC [ C" {
    var buf = [_]u8{ 0x1b, '[', 'C' };
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .arrow_right);
}

test "readKey returns arrow_left for ESC [ D" {
    var buf = [_]u8{ 0x1b, '[', 'D' };
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .arrow_left);
}

test "readKey returns escape for lone ESC byte" {
    var buf = [_]u8{0x1b};
    var fbs = std.io.fixedBufferStream(&buf);
    const key = try input.readKey(fbs.reader());
    try std.testing.expect(key == .escape);
}
