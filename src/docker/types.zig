const std = @import("std");

/// Docker コンテナの型定義。
/// Docker API の /containers/json レスポンスに対応する。
pub const Container = struct {
    id: []const u8,
    names: []const []const u8,
    image: []const u8,
    state: []const u8,
    status: []const u8,

    /// コンテナが実行中かどうかを返す。
    pub fn isRunning(self: Container) bool {
        return std.mem.eql(u8, self.state, "running");
    }

    /// コンテナが終了状態かどうかを返す。
    pub fn isExited(self: Container) bool {
        return std.mem.eql(u8, self.state, "exited");
    }

    /// コンテナ ID の先頭 12 文字を返す。
    /// ID が 12 文字未満の場合は全体を返す。
    pub fn shortId(self: Container) []const u8 {
        const len = @min(self.id.len, 12);
        return self.id[0..len];
    }
};

/// Docker イメージの型定義。
/// Docker API の /images/json レスポンスに対応する。
pub const Image = struct {
    id: []const u8,
    repo_tags: []const []const u8,
    size: u64,

    /// タグのないダングリングイメージかどうかを返す。
    pub fn isDangling(self: Image) bool {
        if (self.repo_tags.len == 0) return true;
        for (self.repo_tags) |tag| {
            if (std.mem.eql(u8, tag, "<none>:<none>")) return true;
        }
        return false;
    }

    /// 表示用タグを返す。タグがない場合は "<none>:<none>" を返す。
    pub fn displayTag(self: Image) []const u8 {
        if (self.repo_tags.len == 0) return "<none>:<none>";
        return self.repo_tags[0];
    }
};

/// Docker ボリュームの型定義。
/// Docker API の /volumes レスポンスに対応する。
pub const Volume = struct {
    name: []const u8,
    driver: []const u8,
    mountpoint: []const u8,
    /// いずれかのコンテナから参照されているかどうか。
    in_use: bool,

    /// どのコンテナにも使われていない孤立ボリュームかどうかを返す。
    pub fn isOrphaned(self: Volume) bool {
        return !self.in_use;
    }
};

/// Docker ネットワークの型定義。
/// Docker API の /networks レスポンスに対応する。
pub const Network = struct {
    id: []const u8,
    name: []const u8,
    driver: []const u8,
    scope: []const u8,
};

/// Docker システムディスク使用量の型定義。
/// Docker API の /system/df レスポンスに対応する。
pub const DiskUsage = struct {
    layers_size: u64,
    containers: []const Container,
    images: []const Image,
    volumes: []const Volume,
};
