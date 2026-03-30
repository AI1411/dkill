const std = @import("std");
const client = @import("../src/docker/client.zig");

// ─── parseHttpResponse ───────────────────────────────────────

test "parseHttpResponse returns body for 200 response" {
    const raw = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"Version\":\"24.0.0\"}";
    const body = try client.parseHttpResponse(std.testing.allocator, raw);
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("{\"Version\":\"24.0.0\"}", body);
}

test "parseHttpResponse returns empty body for 200 response with no body" {
    const raw = "HTTP/1.1 200 OK\r\n\r\n";
    const body = try client.parseHttpResponse(std.testing.allocator, raw);
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("", body);
}

test "parseHttpResponse returns error.HttpError for 404 response" {
    const raw = "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\n\r\n{\"message\":\"No such container\"}";
    try std.testing.expectError(error.HttpError, client.parseHttpResponse(std.testing.allocator, raw));
}

test "parseHttpResponse returns error.HttpError for 500 response" {
    const raw = "HTTP/1.1 500 Internal Server Error\r\n\r\n";
    try std.testing.expectError(error.HttpError, client.parseHttpResponse(std.testing.allocator, raw));
}

test "parseHttpResponse returns error.InvalidResponse for malformed response" {
    const raw = "not an http response";
    try std.testing.expectError(error.InvalidResponse, client.parseHttpResponse(std.testing.allocator, raw));
}

test "parseHttpResponse returns error.InvalidResponse for response without CRLF body separator" {
    const raw = "HTTP/1.1 200 OK\r\nContent-Type: application/json";
    try std.testing.expectError(error.InvalidResponse, client.parseHttpResponse(std.testing.allocator, raw));
}

test "parseHttpResponse handles 201 Created as success" {
    const raw = "HTTP/1.1 201 Created\r\n\r\nok";
    const body = try client.parseHttpResponse(std.testing.allocator, raw);
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("ok", body);
}

test "parseHttpResponse handles 204 No Content as success" {
    const raw = "HTTP/1.1 204 No Content\r\n\r\n";
    const body = try client.parseHttpResponse(std.testing.allocator, raw);
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("", body);
}

// ─── Docker 疎通テスト ─────────────────────────────────────────
// SKIP_DOCKER_TESTS=1 で Docker 未起動環境でもスキップ可能

test "DockerClient.get /v1.45/version succeeds" {
    const skip = std.process.getEnvVarOwned(std.testing.allocator, "SKIP_DOCKER_TESTS") catch null;
    if (skip) |s| {
        defer std.testing.allocator.free(s);
        if (std.mem.eql(u8, s, "1")) return;
    }

    var docker_client = client.DockerClient.init(std.testing.allocator);
    const body = try docker_client.get("/v1.45/version");
    defer std.testing.allocator.free(body);

    try std.testing.expect(body.len > 0);
}
