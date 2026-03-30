const std = @import("std");

// ─── ANSI エスケープコード定数 ───────────────────────────────

pub const RESET = "\x1b[0m";
pub const BOLD = "\x1b[1m";
pub const FG_BLACK = "\x1b[30m";
pub const FG_RED = "\x1b[31m";
pub const FG_GREEN = "\x1b[32m";
pub const FG_YELLOW = "\x1b[33m";
pub const FG_BLUE = "\x1b[34m";
pub const FG_MAGENTA = "\x1b[35m";
pub const FG_CYAN = "\x1b[36m";
pub const FG_WHITE = "\x1b[37m";
pub const BG_BLACK = "\x1b[40m";
pub const BG_WHITE = "\x1b[47m";
pub const BG_BLUE = "\x1b[44m";

/// カーソルをホーム位置に移動して画面をクリアする。
pub fn clearAndHome(writer: anytype) !void {
    try writer.writeAll("\x1b[2J\x1b[H");
}

/// カーソルを指定行列（1-origin）に移動する。
pub fn moveCursor(writer: anytype, row: usize, col: usize) !void {
    try writer.print("\x1b[{d};{d}H", .{ row, col });
}

/// タブバーを描画する。
/// tabs: タブ名の配列、active: アクティブタブのインデックス、cols: 端末幅
pub fn drawTabBar(writer: anytype, tabs: []const []const u8, active: usize, cols: usize) !void {
    _ = cols;
    try writer.writeAll(BG_BLUE ++ FG_WHITE);
    for (tabs, 0..) |tab, i| {
        if (i == active) {
            try writer.print(" " ++ BOLD ++ "{s}" ++ RESET ++ BG_BLUE ++ FG_WHITE ++ " ", .{tab});
        } else {
            try writer.print(" {s} ", .{tab});
        }
        if (i + 1 < tabs.len) {
            try writer.writeAll("|");
        }
    }
    try writer.writeAll(RESET ++ "\n");
}

/// チェックボックス付きリスト行を描画する。
/// checked: 選択済み、selected: カーソル位置、line: 行テキスト、cols: 端末幅
pub fn drawListItem(writer: anytype, checked: bool, selected: bool, line: []const u8, cols: usize) !void {
    _ = cols;
    const checkbox = if (checked) "[x]" else "[ ]";
    if (selected) {
        try writer.print(BG_BLUE ++ FG_WHITE ++ "{s} {s}" ++ RESET ++ "\n", .{ checkbox, line });
    } else {
        try writer.print("{s} {s}\n", .{ checkbox, line });
    }
}

/// ステータスバーを描画する。
pub fn drawStatusBar(writer: anytype, text: []const u8, cols: usize) !void {
    _ = cols;
    try writer.print(BG_BLACK ++ FG_WHITE ++ " {s} " ++ RESET ++ "\n", .{text});
}

/// ヘルプバーを描画する。
pub fn drawHelpBar(writer: anytype, cols: usize) !void {
    _ = cols;
    try writer.writeAll(BG_BLACK ++ FG_WHITE ++
        " j/k:move  Space:select  Tab:tab  a:all  d:delete  q:quit" ++
        RESET ++ "\n");
}

/// 確認ダイアログを画面中央に描画する。
pub fn drawConfirmDialog(writer: anytype, count: usize, size_str: []const u8, rows: usize, cols: usize) !void {
    const dialog_row = rows / 2 - 2;
    const dialog_col = if (cols > 50) (cols - 50) / 2 else 1;
    try moveCursor(writer, dialog_row, dialog_col);
    try writer.print(BOLD ++ "Delete {d} item(s) ({s})? [Enter/Esc]" ++ RESET, .{ count, size_str });
}
