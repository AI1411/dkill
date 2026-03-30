const std = @import("std");
const types = @import("../docker/types.zig");

/// コンテナ一覧を JSON 配列として writer に出力する。
pub fn printContainersJson(writer: anytype, containers: []const types.Container) !void {
    try writer.writeAll("[\n");
    for (containers, 0..) |c, i| {
        try writer.writeAll("  {\n");
        try writer.print("    \"id\": \"{s}\",\n", .{c.Id});
        try writer.writeAll("    \"names\": [");
        for (c.Names, 0..) |name, j| {
            if (j > 0) try writer.writeAll(", ");
            try writer.print("\"{s}\"", .{name});
        }
        try writer.writeAll("],\n");
        try writer.print("    \"image\": \"{s}\",\n", .{c.Image});
        try writer.print("    \"state\": \"{s}\",\n", .{c.State});
        try writer.print("    \"status\": \"{s}\"\n", .{c.Status});
        if (i + 1 < containers.len) {
            try writer.writeAll("  },\n");
        } else {
            try writer.writeAll("  }\n");
        }
    }
    try writer.writeAll("]\n");
}

/// イメージ一覧を JSON 配列として writer に出力する。
pub fn printImagesJson(writer: anytype, images: []const types.Image) !void {
    try writer.writeAll("[\n");
    for (images, 0..) |img, i| {
        try writer.writeAll("  {\n");
        try writer.print("    \"id\": \"{s}\",\n", .{img.Id});
        try writer.writeAll("    \"repoTags\": [");
        for (img.RepoTags, 0..) |tag, j| {
            if (j > 0) try writer.writeAll(", ");
            try writer.print("\"{s}\"", .{tag});
        }
        try writer.writeAll("],\n");
        try writer.print("    \"size\": {d}\n", .{img.Size});
        if (i + 1 < images.len) {
            try writer.writeAll("  },\n");
        } else {
            try writer.writeAll("  }\n");
        }
    }
    try writer.writeAll("]\n");
}

/// ボリューム一覧を JSON 配列として writer に出力する。
pub fn printVolumesJson(writer: anytype, volumes: []const types.Volume) !void {
    try writer.writeAll("[\n");
    for (volumes, 0..) |v, i| {
        try writer.writeAll("  {\n");
        try writer.print("    \"name\": \"{s}\",\n", .{v.Name});
        try writer.print("    \"driver\": \"{s}\",\n", .{v.Driver});
        try writer.print("    \"mountpoint\": \"{s}\"", .{v.Mountpoint});
        if (v.UsageData) |usage| {
            try writer.writeAll(",\n");
            try writer.writeAll("    \"usageData\": {\n");
            try writer.print("      \"refCount\": {d},\n", .{usage.RefCount});
            try writer.print("      \"size\": {d}\n", .{usage.Size});
            try writer.writeAll("    }\n");
        } else {
            try writer.writeAll("\n");
        }
        if (i + 1 < volumes.len) {
            try writer.writeAll("  },\n");
        } else {
            try writer.writeAll("  }\n");
        }
    }
    try writer.writeAll("]\n");
}
