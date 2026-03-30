const std = @import("std");

/// Unix Domain Socket 経由で Docker Engine API と通信するクライアント。
pub const DockerClient = struct {
    allocator: std.mem.Allocator,
    socket_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, socket_path: []const u8) DockerClient {
        return .{
            .allocator = allocator,
            .socket_path = socket_path,
        };
    }

    /// GET リクエストを送信し、デコード済みレスポンスボディを返す。
    /// 返り値はアロケータで確保されたスライス。呼び出し元が解放する必要がある。
    pub fn get(self: *DockerClient, path: []const u8) ![]u8 {
        const raw = try self.sendRequest("GET", path);
        defer self.allocator.free(raw);

        const status_code = try parseStatusCode(raw);
        if (status_code < 200 or status_code >= 300) return error.HttpError;

        const header_end = std.mem.indexOf(u8, raw, "\r\n\r\n") orelse return error.InvalidResponse;
        const headers = raw[0..header_end];
        const body_raw = raw[header_end + 4 ..];

        if (isChunked(headers)) {
            return try decodeChunked(self.allocator, body_raw);
        }
        return try self.allocator.dupe(u8, body_raw);
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
        var buf: [65536]u8 = undefined;
        while (true) {
            const n = try stream.read(&buf);
            if (n == 0) break;
            try response.appendSlice(self.allocator, buf[0..n]);
            // EOF を待たず、レスポンスが完結したら即終了
            if (isResponseComplete(response.items)) break;
        }

        return try response.toOwnedSlice(self.allocator);
    }
};

/// HTTP レスポンスが完結しているか判定する。
/// Content-Length があれば必要バイト数、chunked なら終端マーカーで判断する。
fn isResponseComplete(data: []const u8) bool {
    const header_end = std.mem.indexOf(u8, data, "\r\n\r\n") orelse return false;
    const headers = data[0..header_end];
    const body = data[header_end + 4 ..];

    // Content-Length で判断
    if (getContentLength(headers)) |content_length| {
        return body.len >= content_length;
    }

    // Chunked エンコーディングの終端マーカー "\r\n0\r\n\r\n" で判断
    if (isChunked(headers)) {
        return std.mem.endsWith(u8, data, "\r\n0\r\n\r\n");
    }

    return false;
}

/// Content-Length ヘッダーの値を返す。
fn getContentLength(headers: []const u8) ?usize {
    var it = std.mem.splitScalar(u8, headers, '\n');
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r ");
        const prefix = "content-length:";
        if (trimmed.len > prefix.len and
            std.ascii.eqlIgnoreCase(trimmed[0..prefix.len], prefix))
        {
            const value = std.mem.trim(u8, trimmed[prefix.len..], " ");
            return std.fmt.parseInt(usize, value, 10) catch null;
        }
    }
    return null;
}

/// レスポンスヘッダーに Transfer-Encoding: chunked が含まれるか確認する。
fn isChunked(headers: []const u8) bool {
    var it = std.mem.splitScalar(u8, headers, '\n');
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r ");
        if (std.ascii.eqlIgnoreCase(trimmed, "transfer-encoding: chunked")) {
            return true;
        }
    }
    return false;
}

/// Chunked Transfer Encoding をデコードして生のボディを返す。
fn decodeChunked(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    var pos: usize = 0;
    while (pos < data.len) {
        // チャンクサイズ行を読む
        const line_end = std.mem.indexOf(u8, data[pos..], "\r\n") orelse break;
        const size_str = std.mem.trim(u8, data[pos .. pos + line_end], " \t");
        // チャンク拡張（";"以降）を無視
        const semi = std.mem.indexOfScalar(u8, size_str, ';');
        const hex_str = if (semi) |s| size_str[0..s] else size_str;
        const chunk_size = std.fmt.parseInt(usize, hex_str, 16) catch break;

        pos += line_end + 2;
        if (chunk_size == 0) break; // 最終チャンク

        if (pos + chunk_size > data.len) return error.InvalidChunk;
        try result.appendSlice(allocator, data[pos .. pos + chunk_size]);
        pos += chunk_size + 2; // データ + 末尾 CRLF をスキップ
    }

    return try result.toOwnedSlice(allocator);
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
