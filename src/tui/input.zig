const std = @import("std");
const posix = std.posix;

/// terminal サイズ。
pub const TerminalSize = struct {
    cols: u16,
    rows: u16,
};

/// キーボード入力を表す union。
pub const Key = union(enum) {
    char: u8,
    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,
    enter,
    space,
    tab,
    escape,
    backspace,
    ctrl_c,
    ctrl_d,
    unknown,
};

/// Raw モード制御。
/// enable() で raw モードを有効にし、disable() で元に戻す。
pub const RawMode = struct {
    orig: posix.termios,

    /// Raw モードを有効にして RawMode を返す。
    pub fn enable() !RawMode {
        const fd = posix.STDIN_FILENO;
        const orig = try posix.tcgetattr(fd);
        var raw = orig;

        // エコー・正規モード・シグナル入力を無効化
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;
        raw.lflag.IEXTEN = false;
        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.oflag.OPOST = false;
        raw.cc[@intFromEnum(posix.V.MIN)] = 1;
        raw.cc[@intFromEnum(posix.V.TIME)] = 0;

        try posix.tcsetattr(fd, .FLUSH, raw);
        return RawMode{ .orig = orig };
    }

    /// 元の terminal 設定を復元する。
    pub fn disable(self: RawMode) void {
        posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, self.orig) catch {};
    }
};

/// terminal サイズを ioctl で取得する。
pub fn getTerminalSize() !TerminalSize {
    var ws: posix.winsize = undefined;
    const rc = posix.system.ioctl(posix.STDOUT_FILENO, posix.T.IOCGWINSZ, @intFromPtr(&ws));
    if (rc != 0) return error.IoctlFailed;
    return TerminalSize{ .cols = ws.col, .rows = ws.row };
}

/// reader から 1 文字または escape シーケンスを読み取って Key を返す。
/// reader は readByte() を持つ anytype（std.io.AnyReader など）。
pub fn readKey(reader: anytype) !Key {
    const b = reader.readByte() catch return error.EndOfStream;
    return parseKeyByte(b, reader);
}

/// posix.read で stdin から直接 1 文字または escape シーケンスを読む。
/// TUI メインループから呼び出す。
pub fn readKeyFromStdin() !Key {
    var buf: [1]u8 = undefined;
    const n = try posix.read(posix.STDIN_FILENO, &buf);
    if (n == 0) return error.EndOfStream;
    const b = buf[0];
    if (b != 0x1b) return parseKeyByte(b, DummyReader{});

    // エスケープシーケンスの続きを読む
    var seq: [2]u8 = undefined;
    const n2 = posix.read(posix.STDIN_FILENO, &seq) catch return .escape;
    if (n2 < 2) return .escape;
    if (seq[0] != '[') return .escape;
    return switch (seq[1]) {
        'A' => .arrow_up,
        'B' => .arrow_down,
        'C' => .arrow_right,
        'D' => .arrow_left,
        else => .unknown,
    };
}

/// 1 バイトから Key を返す内部関数。
fn parseKeyByte(b: u8, reader: anytype) Key {
    return switch (b) {
        0x03 => .ctrl_c,
        0x04 => .ctrl_d,
        0x09 => .tab,
        0x0a, 0x0d => .enter,
        0x1b => {
            const b2 = reader.readByte() catch return .escape;
            if (b2 != '[') return .escape;
            const b3 = reader.readByte() catch return .escape;
            return switch (b3) {
                'A' => .arrow_up,
                'B' => .arrow_down,
                'C' => .arrow_right,
                'D' => .arrow_left,
                else => .unknown,
            };
        },
        ' ' => .space,
        0x7f => .backspace,
        else => Key{ .char = b },
    };
}

/// readKeyFromStdin 用のダミーリーダー（使われない）。
const DummyReader = struct {
    pub fn readByte(_: DummyReader) !u8 {
        return error.EndOfStream;
    }
};
