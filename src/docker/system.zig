const std = @import("std");
const types = @import("types.zig");
const size_util = @import("../utils/size.zig");

/// Docker システムディスク使用量をテーブル形式で writer に出力する。
///
/// 出力例:
/// TYPE          TOTAL    ACTIVE   RECLAIMABLE
/// ──────────────────────────────────────────────────────
/// Containers    12       4        234 MB
/// Images        25       8        8.2 GB
/// Volumes       9        3        4.1 GB
/// Build Cache                     2.3 GB
/// ──────────────────────────────────────────────────────
/// Total reclaimable: 14.8 GB
pub fn printDiskUsageTable(writer: anytype, usage: types.DiskUsage) !void {
    const sep = "──────────────────────────────────────────────────────";

    try writer.print("{s:<16}{s:<9}{s:<9}{s}\n", .{ "TYPE", "TOTAL", "ACTIVE", "RECLAIMABLE" });
    try writer.print("{s}\n", .{sep});

    // Containers
    const total_containers = usage.Containers.len;
    var active_containers: usize = 0;
    for (usage.Containers) |c| {
        if (c.isRunning()) active_containers += 1;
    }
    try writer.print("{s:<16}{d:<9}{d:<9}\n", .{ "Containers", total_containers, active_containers });

    // Images
    const total_images = usage.Images.len;
    var active_images: usize = 0;
    var total_images_size: u64 = 0;
    for (usage.Images) |img| {
        if (!img.isDangling()) active_images += 1;
        total_images_size += img.Size;
    }
    var img_size_buf: [16]u8 = undefined;
    const img_size_str = size_util.humanReadable(total_images_size, &img_size_buf);
    try writer.print("{s:<16}{d:<9}{d:<9}{s}\n", .{ "Images", total_images, active_images, img_size_str });

    // Volumes
    const total_volumes = usage.Volumes.len;
    var active_volumes: usize = 0;
    var reclaimable_volume_size: u64 = 0;
    for (usage.Volumes) |v| {
        if (!v.isOrphaned()) {
            active_volumes += 1;
        } else {
            if (v.UsageData) |ud| {
                if (ud.Size > 0) reclaimable_volume_size += @intCast(ud.Size);
            }
        }
    }
    var vol_size_buf: [16]u8 = undefined;
    const vol_size_str = size_util.humanReadable(reclaimable_volume_size, &vol_size_buf);
    try writer.print("{s:<16}{d:<9}{d:<9}{s}\n", .{ "Volumes", total_volumes, active_volumes, vol_size_str });

    // Build Cache (LayersSize)
    var cache_buf: [16]u8 = undefined;
    const cache_str = size_util.humanReadable(usage.LayersSize, &cache_buf);
    try writer.print("{s:<34}{s}\n", .{ "Build Cache", cache_str });

    try writer.print("{s}\n", .{sep});

    // Total reclaimable
    const total_reclaimable: u64 = reclaimable_volume_size + usage.LayersSize;
    var total_buf: [16]u8 = undefined;
    const total_str = size_util.humanReadable(total_reclaimable, &total_buf);
    try writer.print("Total reclaimable: {s}\n", .{total_str});
}
