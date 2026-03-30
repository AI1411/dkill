const std = @import("std");
const commands = @import("../src/cli/commands.zig");

// ─── parse: 引数なし ────────────────────────────────────────
test "parse: no args returns tui" {
    const result = try commands.parse(&.{"dkill"});
    try std.testing.expect(result == .tui);
}

// ─── parse: containers ──────────────────────────────────────
test "parse: containers no flags" {
    const result = try commands.parse(&.{ "dkill", "containers" });
    try std.testing.expect(result == .containers);
    try std.testing.expect(!result.containers.exited);
    try std.testing.expect(!result.containers.json);
}

test "parse: containers --exited" {
    const result = try commands.parse(&.{ "dkill", "containers", "--exited" });
    try std.testing.expect(result == .containers);
    try std.testing.expect(result.containers.exited);
    try std.testing.expect(!result.containers.json);
}

test "parse: containers --json" {
    const result = try commands.parse(&.{ "dkill", "containers", "--json" });
    try std.testing.expect(result == .containers);
    try std.testing.expect(!result.containers.exited);
    try std.testing.expect(result.containers.json);
}

test "parse: containers --exited --json" {
    const result = try commands.parse(&.{ "dkill", "containers", "--exited", "--json" });
    try std.testing.expect(result == .containers);
    try std.testing.expect(result.containers.exited);
    try std.testing.expect(result.containers.json);
}

// ─── parse: images ──────────────────────────────────────────
test "parse: images no flags" {
    const result = try commands.parse(&.{ "dkill", "images" });
    try std.testing.expect(result == .images);
    try std.testing.expect(!result.images.dangling);
    try std.testing.expect(!result.images.json);
}

test "parse: images --dangling" {
    const result = try commands.parse(&.{ "dkill", "images", "--dangling" });
    try std.testing.expect(result == .images);
    try std.testing.expect(result.images.dangling);
}

test "parse: images --dangling --json" {
    const result = try commands.parse(&.{ "dkill", "images", "--dangling", "--json" });
    try std.testing.expect(result == .images);
    try std.testing.expect(result.images.dangling);
    try std.testing.expect(result.images.json);
}

// ─── parse: volumes ─────────────────────────────────────────
test "parse: volumes no flags" {
    const result = try commands.parse(&.{ "dkill", "volumes" });
    try std.testing.expect(result == .volumes);
    try std.testing.expect(!result.volumes.orphaned);
    try std.testing.expect(!result.volumes.json);
}

test "parse: volumes --orphaned" {
    const result = try commands.parse(&.{ "dkill", "volumes", "--orphaned" });
    try std.testing.expect(result == .volumes);
    try std.testing.expect(result.volumes.orphaned);
}

test "parse: volumes --orphaned --json" {
    const result = try commands.parse(&.{ "dkill", "volumes", "--orphaned", "--json" });
    try std.testing.expect(result == .volumes);
    try std.testing.expect(result.volumes.orphaned);
    try std.testing.expect(result.volumes.json);
}

// ─── parse: df ──────────────────────────────────────────────
test "parse: df command" {
    const result = try commands.parse(&.{ "dkill", "df" });
    try std.testing.expect(result == .df);
}

test "parse: df with unknown flag returns error" {
    try std.testing.expectError(
        error.UnknownFlag,
        commands.parse(&.{ "dkill", "df", "--bad" }),
    );
}

// ─── parse: prune ────────────────────────────────────────────
test "parse: prune no flags" {
    const result = try commands.parse(&.{ "dkill", "prune" });
    try std.testing.expect(result == .prune);
    try std.testing.expect(!result.prune.containers);
    try std.testing.expect(!result.prune.images_dangling);
    try std.testing.expect(!result.prune.volumes_orphaned);
    try std.testing.expect(!result.prune.all);
    try std.testing.expect(!result.prune.yes);
    try std.testing.expect(!result.prune.dry_run);
}

test "parse: prune --all --yes --dry-run" {
    const result = try commands.parse(&.{ "dkill", "prune", "--all", "--yes", "--dry-run" });
    try std.testing.expect(result == .prune);
    try std.testing.expect(result.prune.all);
    try std.testing.expect(result.prune.yes);
    try std.testing.expect(result.prune.dry_run);
}

test "parse: prune --containers" {
    const result = try commands.parse(&.{ "dkill", "prune", "--containers" });
    try std.testing.expect(result == .prune);
    try std.testing.expect(result.prune.containers);
    try std.testing.expect(!result.prune.images_dangling);
    try std.testing.expect(!result.prune.volumes_orphaned);
}

test "parse: prune --images-dangling" {
    const result = try commands.parse(&.{ "dkill", "prune", "--images-dangling" });
    try std.testing.expect(result == .prune);
    try std.testing.expect(result.prune.images_dangling);
}

test "parse: prune --volumes-orphaned" {
    const result = try commands.parse(&.{ "dkill", "prune", "--volumes-orphaned" });
    try std.testing.expect(result == .prune);
    try std.testing.expect(result.prune.volumes_orphaned);
}

test "parse: prune unknown flag returns error" {
    try std.testing.expectError(
        error.UnknownFlag,
        commands.parse(&.{ "dkill", "prune", "--bad-flag" }),
    );
}

// ─── parse: help ────────────────────────────────────────────
test "parse: help command" {
    const result = try commands.parse(&.{ "dkill", "help" });
    try std.testing.expect(result == .help);
}

test "parse: --help flag" {
    const result = try commands.parse(&.{ "dkill", "--help" });
    try std.testing.expect(result == .help);
}

test "parse: -h flag" {
    const result = try commands.parse(&.{ "dkill", "-h" });
    try std.testing.expect(result == .help);
}

// ─── parse: エラーケース ─────────────────────────────────────
test "parse: unknown command returns error" {
    try std.testing.expectError(
        error.UnknownCommand,
        commands.parse(&.{ "dkill", "unknown" }),
    );
}

test "parse: unknown flag for containers returns error" {
    try std.testing.expectError(
        error.UnknownFlag,
        commands.parse(&.{ "dkill", "containers", "--bad-flag" }),
    );
}

test "parse: unknown flag for images returns error" {
    try std.testing.expectError(
        error.UnknownFlag,
        commands.parse(&.{ "dkill", "images", "--bad-flag" }),
    );
}

test "parse: unknown flag for volumes returns error" {
    try std.testing.expectError(
        error.UnknownFlag,
        commands.parse(&.{ "dkill", "volumes", "--bad-flag" }),
    );
}

// ─── printUsage ─────────────────────────────────────────────
test "printUsage writes usage text" {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try commands.printUsage(fbs.writer());
    const written = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, written, "Usage:") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "containers") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "images") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "volumes") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "df") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "prune") != null);
}
