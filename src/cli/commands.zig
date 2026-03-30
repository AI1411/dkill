const std = @import("std");

/// CLI で指定できるサブコマンド。
pub const Command = enum {
    containers,
    images,
    volumes,
    help,
};

/// `dkill containers` のフィルタオプション。
pub const ContainerFilter = struct {
    /// --exited: 停止コンテナのみ表示
    exited: bool = false,
    /// --json: JSON 形式で出力
    json: bool = false,
};

/// `dkill images` のフィルタオプション。
pub const ImageFilter = struct {
    /// --dangling: タグのないダングリングイメージのみ表示
    dangling: bool = false,
    /// --json: JSON 形式で出力
    json: bool = false,
};

/// `dkill volumes` のフィルタオプション。
pub const VolumeFilter = struct {
    /// --orphaned: どのコンテナにも使われていないボリュームのみ表示
    orphaned: bool = false,
    /// --json: JSON 形式で出力
    json: bool = false,
};

/// パース結果。コマンドとそれぞれのフィルタを保持する。
pub const ParseResult = union(Command) {
    containers: ContainerFilter,
    images: ImageFilter,
    volumes: VolumeFilter,
    help: void,
};

/// ParseError はコマンドライン引数のパースに失敗したことを表す。
pub const ParseError = error{
    UnknownCommand,
    UnknownFlag,
};

/// コマンドライン引数をパースして ParseResult を返す。
/// args[0] はプログラム名を想定しているため読み飛ばす。
pub fn parse(args: []const []const u8) ParseError!ParseResult {
    // args[0] = argv[0] (プログラム名) をスキップ
    const rest = if (args.len > 0) args[1..] else args;

    if (rest.len == 0) return ParseResult{ .help = {} };

    const cmd_str = rest[0];
    const flags = if (rest.len > 1) rest[1..] else rest[0..0];

    if (std.mem.eql(u8, cmd_str, "containers")) {
        var filter = ContainerFilter{};
        for (flags) |flag| {
            if (std.mem.eql(u8, flag, "--exited")) {
                filter.exited = true;
            } else if (std.mem.eql(u8, flag, "--json")) {
                filter.json = true;
            } else {
                return ParseError.UnknownFlag;
            }
        }
        return ParseResult{ .containers = filter };
    } else if (std.mem.eql(u8, cmd_str, "images")) {
        var filter = ImageFilter{};
        for (flags) |flag| {
            if (std.mem.eql(u8, flag, "--dangling")) {
                filter.dangling = true;
            } else if (std.mem.eql(u8, flag, "--json")) {
                filter.json = true;
            } else {
                return ParseError.UnknownFlag;
            }
        }
        return ParseResult{ .images = filter };
    } else if (std.mem.eql(u8, cmd_str, "volumes")) {
        var filter = VolumeFilter{};
        for (flags) |flag| {
            if (std.mem.eql(u8, flag, "--orphaned")) {
                filter.orphaned = true;
            } else if (std.mem.eql(u8, flag, "--json")) {
                filter.json = true;
            } else {
                return ParseError.UnknownFlag;
            }
        }
        return ParseResult{ .volumes = filter };
    } else if (std.mem.eql(u8, cmd_str, "help") or std.mem.eql(u8, cmd_str, "--help") or std.mem.eql(u8, cmd_str, "-h")) {
        return ParseResult{ .help = {} };
    } else {
        return ParseError.UnknownCommand;
    }
}

/// 使い方を標準出力に表示する。
pub fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: dkill <command> [flags]
        \\
        \\Commands:
        \\  containers  List containers
        \\  images      List images
        \\  volumes     List volumes
        \\  help        Show this help message
        \\
        \\Flags for containers:
        \\  --exited    Show only exited containers
        \\  --json      Output as JSON
        \\
        \\Flags for images:
        \\  --dangling  Show only dangling images
        \\  --json      Output as JSON
        \\
        \\Flags for volumes:
        \\  --orphaned  Show only orphaned volumes
        \\  --json      Output as JSON
        \\
    );
}
