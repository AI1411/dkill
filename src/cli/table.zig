const std = @import("std");
const types = @import("../docker/types.zig");
const size_util = @import("../utils/size.zig");

/// コンテナ一覧をテーブル形式で writer に出力する。
pub fn printContainers(writer: anytype, containers: []const types.Container) !void {
    try writer.writeAll("CONTAINER ID    IMAGE                           STATUS\n");
    try writer.writeAll("------------    -----                           ------\n");
    for (containers) |c| {
        const name = if (c.Names.len > 0) c.Names[0] else "(no name)";
        try writer.print("{s:<16}{s:<32}{s}\n", .{
            c.shortId(),
            c.Image,
            name,
        });
        _ = c.Status;
    }
}

/// コンテナ一覧をテーブル形式で writer に出力する（詳細版: ID / Names / Image / State / Status）。
pub fn printContainersDetailed(writer: anytype, containers: []const types.Container) !void {
    try writer.writeAll("CONTAINER ID    NAMES                           IMAGE                           STATE       STATUS\n");
    try writer.writeAll("------------    -----                           -----                           -----       ------\n");
    for (containers) |c| {
        const name = if (c.Names.len > 0) c.Names[0] else "(no name)";
        try writer.print("{s:<16}{s:<32}{s:<32}{s:<12}{s}\n", .{
            c.shortId(),
            name,
            c.Image,
            c.State,
            c.Status,
        });
    }
}

/// イメージ一覧をテーブル形式で writer に出力する。
pub fn printImages(writer: anytype, images: []const types.Image) !void {
    try writer.writeAll("IMAGE ID        REPOSITORY:TAG                  SIZE\n");
    try writer.writeAll("--------        --------------                  ----\n");
    for (images) |img| {
        var size_buf: [16]u8 = undefined;
        const size_str = size_util.humanReadable(img.Size, &size_buf);
        const short_id = if (img.Id.len >= 12) img.Id[0..12] else img.Id;
        try writer.print("{s:<16}{s:<32}{s}\n", .{
            short_id,
            img.displayTag(),
            size_str,
        });
    }
}

/// ボリューム一覧をテーブル形式で writer に出力する。
pub fn printVolumes(writer: anytype, volumes: []const types.Volume) !void {
    try writer.writeAll("VOLUME NAME                     DRIVER      MOUNTPOINT\n");
    try writer.writeAll("-----------                     ------      ----------\n");
    for (volumes) |v| {
        try writer.print("{s:<32}{s:<12}{s}\n", .{
            v.Name,
            v.Driver,
            v.Mountpoint,
        });
    }
}
