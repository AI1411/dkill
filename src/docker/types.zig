const std = @import("std");

/// Docker コンテナの型定義。
/// Docker API の /containers/json レスポンスに対応する。
/// フィールド名は Docker API の JSON キー名に合わせている（PascalCase）。
pub const Container = struct {
    Id: []const u8,
    Names: []const []const u8,
    Image: []const u8,
    State: []const u8,
    Status: []const u8,

    /// コンテナが実行中かどうかを返す。
    pub fn isRunning(self: Container) bool {
        return std.mem.eql(u8, self.State, "running");
    }

    /// コンテナが終了状態かどうかを返す。
    pub fn isExited(self: Container) bool {
        return std.mem.eql(u8, self.State, "exited");
    }

    /// コンテナ ID の先頭 12 文字を返す。
    /// ID が 12 文字未満の場合は全体を返す。
    pub fn shortId(self: Container) []const u8 {
        const len = @min(self.Id.len, 12);
        return self.Id[0..len];
    }
};

/// Docker イメージの型定義。
/// Docker API の /images/json レスポンスに対応する。
/// フィールド名は Docker API の JSON キー名に合わせている（PascalCase）。
pub const Image = struct {
    Id: []const u8,
    RepoTags: []const []const u8,
    Size: u64,

    /// タグのないダングリングイメージかどうかを返す。
    pub fn isDangling(self: Image) bool {
        if (self.RepoTags.len == 0) return true;
        for (self.RepoTags) |tag| {
            if (std.mem.eql(u8, tag, "<none>:<none>")) return true;
        }
        return false;
    }

    /// 表示用タグを返す。タグがない場合は "<none>:<none>" を返す。
    pub fn displayTag(self: Image) []const u8 {
        if (self.RepoTags.len == 0) return "<none>:<none>";
        return self.RepoTags[0];
    }
};

/// Docker ボリュームの UsageData。
/// Docker API の /volumes および /system/df レスポンスに含まれる。
pub const VolumeUsageData = struct {
    RefCount: i64,
    Size: i64,
};

/// Docker ボリュームの型定義。
/// Docker API の /volumes レスポンスに対応する。
/// フィールド名は Docker API の JSON キー名に合わせている（PascalCase）。
pub const Volume = struct {
    Name: []const u8,
    Driver: []const u8,
    Mountpoint: []const u8,
    UsageData: ?VolumeUsageData = null,

    /// どのコンテナにも使われていない孤立ボリュームかどうかを返す。
    /// UsageData が nil または RefCount が 0 の場合に孤立と判断する。
    pub fn isOrphaned(self: Volume) bool {
        if (self.UsageData) |usage| {
            return usage.RefCount == 0;
        }
        return true;
    }
};

/// Docker ネットワークの型定義。
/// Docker API の /networks レスポンスに対応する。
/// フィールド名は Docker API の JSON キー名に合わせている（PascalCase）。
pub const Network = struct {
    Id: []const u8,
    Name: []const u8,
    Driver: []const u8,
    Scope: []const u8,
};

/// Docker システムディスク使用量の型定義。
/// Docker API の /system/df レスポンスに対応する。
/// フィールド名は Docker API の JSON キー名に合わせている（PascalCase）。
pub const DiskUsage = struct {
    LayersSize: u64,
    Containers: []const Container,
    Images: []const Image,
    Volumes: []const Volume,
};
