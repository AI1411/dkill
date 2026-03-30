const std = @import("std");

// ─── ANSI エスケープコード定数 ───────────────────────────────

pub const RESET = "\x1b[0m";
pub const BOLD = "\x1b[1m";
pub const DIM = "\x1b[2m";
pub const FG_BLACK = "\x1b[30m";
pub const FG_RED = "\x1b[31m";
pub const FG_GREEN = "\x1b[32m";
pub const FG_YELLOW = "\x1b[33m";
pub const FG_BLUE = "\x1b[34m";
pub const FG_MAGENTA = "\x1b[35m";
pub const FG_CYAN = "\x1b[36m";
pub const FG_WHITE = "\x1b[37m";
pub const FG_BRIGHT_BLACK = "\x1b[90m";
pub const FG_BRIGHT_RED = "\x1b[91m";
pub const FG_BRIGHT_GREEN = "\x1b[92m";
pub const FG_BRIGHT_YELLOW = "\x1b[93m";
pub const FG_BRIGHT_CYAN = "\x1b[96m";
pub const FG_BRIGHT_WHITE = "\x1b[97m";
pub const BG_BLACK = "\x1b[40m";
pub const BG_BLUE = "\x1b[44m";
pub const BG_WHITE = "\x1b[47m";
pub const BG_DARK = "\x1b[100m"; // bright black = dark gray

/// リストアイテムの表示状態。
pub const ItemStatus = enum {
    normal,
    running, // 実行中コンテナ → 緑
    exited, // 停止コンテナ → グレー
    warning, // dangling image / orphaned volume → 黄
};

/// カーソルをホーム位置に移動して画面をクリアする。
pub fn clearAndHome(writer: anytype) !void {
    try writer.writeAll("\x1b[2J\x1b[H");
}

/// カーソルを指定行列（1-origin）に移動する。
pub fn moveCursor(writer: anytype, row: usize, col: usize) !void {
    try writer.print("\x1b[{d};{d}H", .{ row, col });
}

/// タブバーを描画する。
pub fn drawTabBar(writer: anytype, tabs: []const []const u8, active: usize, cols: usize) !void {
    _ = cols;
    try writer.writeAll(BG_BLUE ++ FG_BRIGHT_WHITE);
    for (tabs, 0..) |tab, i| {
        if (i == active) {
            try writer.print(" " ++ BOLD ++ FG_BRIGHT_WHITE ++ "{s}" ++ RESET ++ BG_BLUE ++ FG_BRIGHT_WHITE ++ " ", .{tab});
        } else {
            try writer.print(" {s} ", .{tab});
        }
        if (i + 1 < tabs.len) try writer.writeAll(" | ");
    }
    try writer.writeAll(RESET ++ "\r\n");
}

/// カラムヘッダーを描画する。
pub fn drawColumnHeader(writer: anytype, text: []const u8, cols: usize) !void {
    _ = cols;
    try writer.print(BOLD ++ FG_BRIGHT_BLACK ++ "    {s}" ++ RESET ++ "\r\n", .{text});
}

/// チェックボックス付きリスト行を描画する。
pub fn drawListItem(
    writer: anytype,
    checked: bool,
    is_cursor: bool,
    deletable: bool,
    status: ItemStatus,
    line: []const u8,
    cols: usize,
) !void {
    _ = cols;

    // チェックボックス文字列
    const checkbox = if (checked) "[x]" else if (!deletable) "[-]" else "[ ]";

    // チェックボックスの色
    const cb_color = if (checked)
        FG_BRIGHT_CYAN ++ BOLD
    else if (!deletable)
        FG_BRIGHT_BLACK
    else
        FG_WHITE;

    // ラベルの色
    const label_color = switch (status) {
        .running => FG_BRIGHT_GREEN,
        .exited => FG_BRIGHT_BLACK,
        .warning => FG_BRIGHT_YELLOW,
        .normal => FG_WHITE,
    };

    if (is_cursor) {
        // カーソル行: ダークグレー背景 + 行末まで塗りつぶし
        try writer.writeAll(BG_DARK);
        try writer.print(" {s}{s}" ++ RESET ++ BG_DARK ++ " {s}{s}" ++ RESET ++ "\x1b[K\r\n", .{
            cb_color, checkbox, label_color, line,
        });
    } else {
        try writer.print(" {s}{s}" ++ RESET ++ " {s}{s}" ++ RESET ++ "\r\n", .{
            cb_color, checkbox, label_color, line,
        });
    }
}

/// ステータスバーを描画する。
pub fn drawStatusBar(writer: anytype, text: []const u8, cols: usize) !void {
    _ = cols;
    try writer.print(BG_BLACK ++ FG_BRIGHT_WHITE ++ BOLD ++ " {s} " ++ RESET ++ "\r\n", .{text});
}

/// ヘルプバーを描画する。
pub fn drawHelpBar(writer: anytype, cols: usize) !void {
    _ = cols;
    try writer.writeAll(
        FG_BRIGHT_BLACK ++
            " j/k:↑↓  Space:select  Tab:tab  a:all  d:delete  q:quit" ++
            RESET ++ "\r\n",
    );
}

/// 確認ダイアログを画面中央に描画する。
pub fn drawConfirmDialog(writer: anytype, count: usize, size_str: []const u8, rows: usize, cols: usize) !void {
    const dialog_row = rows / 2 - 2;
    const dialog_col = if (cols > 52) (cols - 52) / 2 else 1;
    try moveCursor(writer, dialog_row, dialog_col);
    try writer.print(
        BOLD ++ FG_BRIGHT_YELLOW ++ "  Delete {d} item(s) ({s})? [Enter/Esc]  " ++ RESET,
        .{ count, size_str },
    );
}
