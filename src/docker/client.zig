const std = @import("std");

/// Unix Domain Socket 経由で Docker Engine API と通信するクライアント。
pub const DockerClient = struct {
    allocator: std.mem.Allocator,
    socket_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) DockerClient {
        return .{
            .allocator = allocator,
            .socket_path = "/var/run/docker.sock",
        };
    }

    /// GET リクエストを送信し、レスポンスボディを返す。
    /// 返り値はアロケータで確保されたスライス。呼び出し元が解放する必要がある。
    pub fn get(self: *DockerClient, path: []const u8) ![]const u8 {
        const raw = try self.sendRequest("GET", path);
        defer self.allocator.free(raw);
        return try parseHttpResponse(self.allocator, raw);
    }

    /// DELETE リクエストを送信し、ステータスコードを返す。
    pub fn delete(self: *DockerClient, path: []const u8) !u16 {
        const raw = try self.sendRequest("DELETE", path);
        defer self.allocator.free(raw);
        return try parseStatusCode(raw);
    }

    /// POST リクエストを送信し、ステータスコードを返す。
    pub fn post(self: *DockerClient, path: []const u8) !u16 {
        const raw = try self.sendRequest("POST", path);
        defer self.allocator.free(raw);
        return try parseStatusCode(raw);
    }

    fn sendRequest(self: *DockerClient, method: []const u8, path: []const u8) ![]u8 {
        const stream = try std.net.connectUnixSocket(self.socket_path);
        defer stream.close();

        const request_str = try std.fmt.allocPrint(
            self.allocator,
            "{s} {s} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n",
            .{ method, path },
        );
        defer self.allocator.free(request_str);

        try stream.writeAll(request_str);

        var response = std.ArrayListUnmanaged(u8){};
        defer response.deinit(self.allocator);
        var buf: [4096]u8 = undefined;
        while (true) {
            const n = try stream.read(&buf);
            if (n == 0) break;
            try response.appendSlice(self.allocator, buf[0..n]);
        }

        return try response.toOwnedSlice(self.allocator);
    }
};

/// HTTP/1.1 レスポンスをパースしてボディを返す。
/// ステータスコードが 2xx でない場合はエラーを返す。
/// 返り値はアロケータで確保されたスライス。呼び出し元が解放する必要がある。
pub fn parseHttpResponse(allocator: std.mem.Allocator, raw: []const u8) ![]const u8 {
    const status_code = try parseStatusCode(raw);
    if (status_code < 200 or status_code >= 300) {
        return error.HttpError;
    }

    const header_end = std.mem.indexOf(u8, raw, "\r\n\r\n") orelse return error.InvalidResponse;
    const body = raw[header_end + 4 ..];
    return try allocator.dupe(u8, body);
}

fn parseStatusCode(raw: []const u8) !u16 {
    const first_line_end = std.mem.indexOf(u8, raw, "\r\n") orelse return error.InvalidResponse;
    const first_line = raw[0..first_line_end];

    // "HTTP/1.1 200 OK" のような形式をパース
    var iter = std.mem.splitScalar(u8, first_line, ' ');
    _ = iter.next() orelse return error.InvalidResponse; // "HTTP/1.1"
    const status_str = iter.next() orelse return error.InvalidResponse; // "200"
    return std.fmt.parseInt(u16, status_str, 10) catch return error.InvalidResponse;
}
