const std = @import("std");
const render = @import("../src/tui/render.zig");

// ─── ANSI 定数 ───────────────────────────────────────────────

test "ANSI reset constant is correct" {
    try std.testing.expectEqualStrings("\x1b[0m", render.RESET);
}

test "ANSI bold constant is correct" {
    try std.testing.expectEqualStrings("\x1b[1m", render.BOLD);
}

// ─── drawTabBar ──────────────────────────────────────────────

test "drawTabBar includes tab names" {
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const tabs = [_][]const u8{ "Containers", "Images", "Volumes" };
    try render.drawTabBar(fbs.writer(), &tabs, 0, 80);
    const out = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, out, "Containers") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "Images") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "Volumes") != null);
}

test "drawTabBar highlights active tab with bold" {
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const tabs = [_][]const u8{ "Containers", "Images" };
    try render.drawTabBar(fbs.writer(), &tabs, 0, 80);
    const out = fbs.getWritten();
    // アクティブタブは BOLD を含む
    try std.testing.expect(std.mem.indexOf(u8, out, render.BOLD) != null);
}

// ─── drawListItem ────────────────────────────────────────────

test "drawListItem includes item text" {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try render.drawListItem(fbs.writer(), false, false, true, .normal, "my-container  nginx  running", 80);
    const out = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, out, "my-container") != null);
}

test "drawListItem shows checkbox unchecked" {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try render.drawListItem(fbs.writer(), false, false, true, .normal, "item", 80);
    const out = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, out, "[ ]") != null);
}

test "drawListItem shows checkbox checked" {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try render.drawListItem(fbs.writer(), true, false, true, .normal, "item", 80);
    const out = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, out, "[x]") != null);
}

// ─── drawStatusBar ───────────────────────────────────────────

test "drawStatusBar includes text" {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try render.drawStatusBar(fbs.writer(), "3 selected (1.2 MB)", 80);
    const out = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, out, "3 selected") != null);
}

// ─── drawHelpBar ─────────────────────────────────────────────

test "drawHelpBar includes key hints" {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try render.drawHelpBar(fbs.writer(), 80);
    const out = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, out, "q") != null);
}
