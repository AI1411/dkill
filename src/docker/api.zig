const std = @import("std");
const client = @import("client.zig");
const types = @import("types.zig");

const API_VERSION = "v1.45";

/// Docker Engine API ラッパー。
/// DockerClient を使って各エンドポイントを呼び出し、型付きの結果を返す。
pub const DockerApi = struct {
    c: client.DockerClient,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, socket_path: []const u8) DockerApi {
        return DockerApi{
            .c = client.DockerClient.init(allocator, socket_path),
            .allocator = allocator,
        };
    }

    /// コンテナ一覧取得（all=true で停止コンテナも含む）。
    /// 返り値のスライスおよび各フィールドの文字列は呼び出し元が解放する必要がある。
    pub fn listContainers(self: *DockerApi) ![]types.Container {
        const body = try self.c.get("/" ++ API_VERSION ++ "/containers/json?all=true&size=true");
        defer self.allocator.free(body);
        return parseContainers(self.allocator, body);
    }

    /// イメージ一覧取得（all=true で中間イメージも含む）。
    /// 返り値のスライスおよび各フィールドの文字列は呼び出し元が解放する必要がある。
    pub fn listImages(self: *DockerApi) ![]types.Image {
        const body = try self.c.get("/" ++ API_VERSION ++ "/images/json?all=true");
        defer self.allocator.free(body);
        return parseImages(self.allocator, body);
    }

    /// ボリューム一覧取得。
    /// 返り値のスライスおよび各フィールドの文字列は呼び出し元が解放する必要がある。
    pub fn listVolumes(self: *DockerApi) ![]types.Volume {
        const body = try self.c.get("/" ++ API_VERSION ++ "/volumes");
        defer self.allocator.free(body);
        return parseVolumes(self.allocator, body);
    }

    /// コンテナ削除（force=true）。
    pub fn removeContainer(self: *DockerApi, id: []const u8) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/{s}/containers/{s}?force=true",
            .{ API_VERSION, id },
        );
        defer self.allocator.free(path);
        const status = try self.c.delete(path);
        if (status != 204) return error.DeleteFailed;
    }

    /// コンテナ停止。
    pub fn stopContainer(self: *DockerApi, id: []const u8) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/{s}/containers/{s}/stop",
            .{ API_VERSION, id },
        );
        defer self.allocator.free(path);
        const status = try self.c.post(path);
        if (status != 204 and status != 304) return error.StopFailed;
    }

    /// イメージ削除。
    pub fn removeImage(self: *DockerApi, id: []const u8) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/{s}/images/{s}",
            .{ API_VERSION, id },
        );
        defer self.allocator.free(path);
        const status = try self.c.delete(path);
        if (status != 200) return error.DeleteFailed;
    }

    /// ボリューム削除。
    pub fn removeVolume(self: *DockerApi, name: []const u8) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/{s}/volumes/{s}",
            .{ API_VERSION, name },
        );
        defer self.allocator.free(path);
        const status = try self.c.delete(path);
        if (status != 204) return error.DeleteFailed;
    }

    /// システムディスク使用量取得。
    /// 返り値のスライスおよび各フィールドの文字列は呼び出し元が解放する必要がある。
    pub fn getDiskUsage(self: *DockerApi) !types.DiskUsage {
        const body = try self.c.get("/" ++ API_VERSION ++ "/system/df");
        defer self.allocator.free(body);
        return parseDiskUsage(self.allocator, body);
    }
};

/// GET /v1.45/containers/json のレスポンス JSON を []types.Container にパースする。
/// 返り値の各フィールド文字列は allocator で確保されているため、呼び出し元が解放する必要がある。
pub fn parseContainers(allocator: std.mem.Allocator, body: []const u8) ![]types.Container {
    const parsed = try std.json.parseFromSlice([]types.Container, allocator, body, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const result = try allocator.alloc(types.Container, parsed.value.len);
    var count: usize = 0;
    errdefer {
        for (result[0..count]) |c| {
            allocator.free(c.Id);
            allocator.free(c.Image);
            allocator.free(c.State);
            allocator.free(c.Status);
            for (c.Names) |name| allocator.free(name);
            allocator.free(c.Names);
        }
        allocator.free(result);
    }

    for (parsed.value) |c| {
        const names = try allocator.alloc([]const u8, c.Names.len);
        var nc: usize = 0;
        errdefer {
            for (names[0..nc]) |name| allocator.free(name);
            allocator.free(names);
        }
        for (c.Names) |name| {
            names[nc] = try allocator.dupe(u8, name);
            nc += 1;
        }

        const id = try allocator.dupe(u8, c.Id);
        errdefer allocator.free(id);
        const image = try allocator.dupe(u8, c.Image);
        errdefer allocator.free(image);
        const state = try allocator.dupe(u8, c.State);
        errdefer allocator.free(state);
        const status = try allocator.dupe(u8, c.Status);
        errdefer allocator.free(status);

        result[count] = types.Container{
            .Id = id,
            .Names = names,
            .Image = image,
            .State = state,
            .Status = status,
        };
        count += 1;
    }
    return result;
}

/// GET /v1.45/images/json のレスポンス JSON を []types.Image にパースする。
/// 返り値の各フィールド文字列は allocator で確保されているため、呼び出し元が解放する必要がある。
pub fn parseImages(allocator: std.mem.Allocator, body: []const u8) ![]types.Image {
    const parsed = try std.json.parseFromSlice([]types.Image, allocator, body, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const result = try allocator.alloc(types.Image, parsed.value.len);
    var count: usize = 0;
    errdefer {
        for (result[0..count]) |img| {
            allocator.free(img.Id);
            for (img.RepoTags) |tag| allocator.free(tag);
            allocator.free(img.RepoTags);
        }
        allocator.free(result);
    }

    for (parsed.value) |img| {
        const tags = try allocator.alloc([]const u8, img.RepoTags.len);
        var tc: usize = 0;
        errdefer {
            for (tags[0..tc]) |tag| allocator.free(tag);
            allocator.free(tags);
        }
        for (img.RepoTags) |tag| {
            tags[tc] = try allocator.dupe(u8, tag);
            tc += 1;
        }

        const id = try allocator.dupe(u8, img.Id);
        errdefer allocator.free(id);

        result[count] = types.Image{
            .Id = id,
            .RepoTags = tags,
            .Size = img.Size,
        };
        count += 1;
    }
    return result;
}

const VolumesResponse = struct {
    Volumes: []const types.Volume,
};

/// GET /v1.45/system/df のレスポンス JSON を types.DiskUsage にパースする。
/// 返り値の各フィールド文字列は allocator で確保されているため、freeDiskUsage で解放する必要がある。
pub fn parseDiskUsage(allocator: std.mem.Allocator, body: []const u8) !types.DiskUsage {
    const parsed = try std.json.parseFromSlice(types.DiskUsage, allocator, body, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const v = parsed.value;

    // Containers をディープコピー
    const containers = try allocator.alloc(types.Container, v.Containers.len);
    var ci: usize = 0;
    errdefer {
        for (containers[0..ci]) |c| {
            allocator.free(c.Id);
            allocator.free(c.Image);
            allocator.free(c.State);
            allocator.free(c.Status);
            for (c.Names) |name| allocator.free(name);
            allocator.free(c.Names);
        }
        allocator.free(containers);
    }
    for (v.Containers) |c| {
        const names = try allocator.alloc([]const u8, c.Names.len);
        var nc: usize = 0;
        errdefer {
            for (names[0..nc]) |n| allocator.free(n);
            allocator.free(names);
        }
        for (c.Names) |n| {
            names[nc] = try allocator.dupe(u8, n);
            nc += 1;
        }
        containers[ci] = .{
            .Id = try allocator.dupe(u8, c.Id),
            .Names = names,
            .Image = try allocator.dupe(u8, c.Image),
            .State = try allocator.dupe(u8, c.State),
            .Status = try allocator.dupe(u8, c.Status),
        };
        ci += 1;
    }

    // Images をディープコピー
    const images = try allocator.alloc(types.Image, v.Images.len);
    var ii: usize = 0;
    errdefer {
        for (images[0..ii]) |img| {
            allocator.free(img.Id);
            for (img.RepoTags) |tag| allocator.free(tag);
            allocator.free(img.RepoTags);
        }
        allocator.free(images);
    }
    for (v.Images) |img| {
        const tags = try allocator.alloc([]const u8, img.RepoTags.len);
        var tc: usize = 0;
        errdefer {
            for (tags[0..tc]) |tag| allocator.free(tag);
            allocator.free(tags);
        }
        for (img.RepoTags) |tag| {
            tags[tc] = try allocator.dupe(u8, tag);
            tc += 1;
        }
        images[ii] = .{
            .Id = try allocator.dupe(u8, img.Id),
            .RepoTags = tags,
            .Size = img.Size,
        };
        ii += 1;
    }

    // Volumes をディープコピー
    const volumes = try allocator.alloc(types.Volume, v.Volumes.len);
    var vi: usize = 0;
    errdefer {
        for (volumes[0..vi]) |vol| {
            allocator.free(vol.Name);
            allocator.free(vol.Driver);
            allocator.free(vol.Mountpoint);
        }
        allocator.free(volumes);
    }
    for (v.Volumes) |vol| {
        volumes[vi] = .{
            .Name = try allocator.dupe(u8, vol.Name),
            .Driver = try allocator.dupe(u8, vol.Driver),
            .Mountpoint = try allocator.dupe(u8, vol.Mountpoint),
            .UsageData = vol.UsageData,
        };
        vi += 1;
    }

    return types.DiskUsage{
        .LayersSize = v.LayersSize,
        .Containers = containers,
        .Images = images,
        .Volumes = volumes,
    };
}

/// parseDiskUsage で確保したメモリを解放する。
pub fn freeDiskUsage(allocator: std.mem.Allocator, usage: types.DiskUsage) void {
    for (usage.Containers) |c| {
        allocator.free(c.Id);
        allocator.free(c.Image);
        allocator.free(c.State);
        allocator.free(c.Status);
        for (c.Names) |name| allocator.free(name);
        allocator.free(c.Names);
    }
    allocator.free(usage.Containers);

    for (usage.Images) |img| {
        allocator.free(img.Id);
        for (img.RepoTags) |tag| allocator.free(tag);
        allocator.free(img.RepoTags);
    }
    allocator.free(usage.Images);

    for (usage.Volumes) |vol| {
        allocator.free(vol.Name);
        allocator.free(vol.Driver);
        allocator.free(vol.Mountpoint);
    }
    allocator.free(usage.Volumes);
}

/// GET /v1.45/volumes のレスポンス JSON を []types.Volume にパースする。
/// 返り値の各フィールド文字列は allocator で確保されているため、呼び出し元が解放する必要がある。
pub fn parseVolumes(allocator: std.mem.Allocator, body: []const u8) ![]types.Volume {
    const parsed = try std.json.parseFromSlice(VolumesResponse, allocator, body, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const result = try allocator.alloc(types.Volume, parsed.value.Volumes.len);
    var count: usize = 0;
    errdefer {
        for (result[0..count]) |v| {
            allocator.free(v.Name);
            allocator.free(v.Driver);
            allocator.free(v.Mountpoint);
        }
        allocator.free(result);
    }

    for (parsed.value.Volumes) |v| {
        const name = try allocator.dupe(u8, v.Name);
        errdefer allocator.free(name);
        const driver = try allocator.dupe(u8, v.Driver);
        errdefer allocator.free(driver);
        const mountpoint = try allocator.dupe(u8, v.Mountpoint);
        errdefer allocator.free(mountpoint);

        result[count] = types.Volume{
            .Name = name,
            .Driver = driver,
            .Mountpoint = mountpoint,
            .UsageData = v.UsageData,
        };
        count += 1;
    }
    return result;
}
