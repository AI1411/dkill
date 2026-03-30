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

    /// イメージ一覧取得。
    /// 返り値のスライスおよび各フィールドの文字列は呼び出し元が解放する必要がある。
    pub fn listImages(self: *DockerApi) ![]types.Image {
        const body = try self.c.get("/" ++ API_VERSION ++ "/images/json");
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
};

/// GET /v1.45/containers/json のレスポンス JSON を []types.Container にパースする。
/// 返り値の各フィールド文字列は allocator で確保されているため、呼び出し元が解放する必要がある。
pub fn parseContainers(allocator: std.mem.Allocator, body: []const u8) ![]types.Container {
    const parsed = try std.json.parseFromSlice([]types.Container, allocator, body, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const result = try allocator.alloc(types.Container, parsed.value.len);
    for (parsed.value, 0..) |c, i| {
        const names = try allocator.alloc([]const u8, c.Names.len);
        for (c.Names, 0..) |name, j| {
            names[j] = try allocator.dupe(u8, name);
        }
        result[i] = types.Container{
            .Id = try allocator.dupe(u8, c.Id),
            .Names = names,
            .Image = try allocator.dupe(u8, c.Image),
            .State = try allocator.dupe(u8, c.State),
            .Status = try allocator.dupe(u8, c.Status),
        };
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
    for (parsed.value, 0..) |img, i| {
        const tags = try allocator.alloc([]const u8, img.RepoTags.len);
        for (img.RepoTags, 0..) |tag, j| {
            tags[j] = try allocator.dupe(u8, tag);
        }
        result[i] = types.Image{
            .Id = try allocator.dupe(u8, img.Id),
            .RepoTags = tags,
            .Size = img.Size,
        };
    }
    return result;
}

const VolumesResponse = struct {
    Volumes: []const types.Volume,
};

/// GET /v1.45/volumes のレスポンス JSON を []types.Volume にパースする。
/// 返り値の各フィールド文字列は allocator で確保されているため、呼び出し元が解放する必要がある。
pub fn parseVolumes(allocator: std.mem.Allocator, body: []const u8) ![]types.Volume {
    const parsed = try std.json.parseFromSlice(VolumesResponse, allocator, body, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const result = try allocator.alloc(types.Volume, parsed.value.Volumes.len);
    for (parsed.value.Volumes, 0..) |v, i| {
        result[i] = types.Volume{
            .Name = try allocator.dupe(u8, v.Name),
            .Driver = try allocator.dupe(u8, v.Driver),
            .Mountpoint = try allocator.dupe(u8, v.Mountpoint),
            .UsageData = v.UsageData,
        };
    }
    return result;
}
