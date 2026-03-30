const std = @import("std");

/// リスト行を表す構造体。
pub const SelectableItem = struct {
    /// リソースの ID（コンテナ ID、イメージ ID、ボリューム名）
    id: []const u8,
    /// 画面表示用テキスト
    label: []const u8,
    /// 削除可能かどうか（running コンテナは false）
    deletable: bool,
    /// 選択状態
    selected: bool,
    /// 表示カラー用ステータス
    status: @import("render.zig").ItemStatus = .normal,
};

/// チェックボックス付きリストウィジェット。
pub const List = struct {
    items: []SelectableItem,
    cursor: usize,
    scroll_offset: usize,
    visible_rows: usize,

    pub fn init(items: []SelectableItem, visible_rows: usize) List {
        return List{
            .items = items,
            .cursor = 0,
            .scroll_offset = 0,
            .visible_rows = visible_rows,
        };
    }

    /// カーソルを 1 行下に移動する。スクロールも追従する。
    pub fn moveDown(self: *List) void {
        if (self.items.len == 0) return;
        if (self.cursor + 1 >= self.items.len) return;
        self.cursor += 1;
        if (self.cursor >= self.scroll_offset + self.visible_rows) {
            self.scroll_offset = self.cursor - self.visible_rows + 1;
        }
    }

    /// カーソルを 1 行上に移動する。スクロールも追従する。
    pub fn moveUp(self: *List) void {
        if (self.cursor == 0) return;
        self.cursor -= 1;
        if (self.cursor < self.scroll_offset) {
            self.scroll_offset = self.cursor;
        }
    }

    /// 現在カーソル行の選択状態を切り替える。deletable でない行は無視。
    pub fn toggleCurrent(self: *List) void {
        if (self.items.len == 0) return;
        const item = &self.items[self.cursor];
        if (!item.deletable) return;
        item.selected = !item.selected;
    }

    /// deletable なすべての行を選択する。
    pub fn selectAll(self: *List) void {
        for (self.items) |*item| {
            if (item.deletable) item.selected = true;
        }
    }

    /// すべての選択を解除する。
    pub fn deselectAll(self: *List) void {
        for (self.items) |*item| {
            item.selected = false;
        }
    }

    /// 選択済みアイテム数を返す。
    pub fn selectedCount(self: *const List) usize {
        var count: usize = 0;
        for (self.items) |item| {
            if (item.selected) count += 1;
        }
        return count;
    }

    /// 選択済みアイテムの合計サイズを返す（i64、不明なら 0）。
    pub fn selectedSize(self: *const List) i64 {
        _ = self;
        return 0;
    }

    /// visible_rows 分だけリスト行を描画する。
    pub fn draw(self: *const List, writer: anytype, cols: usize) !void {
        const render = @import("render.zig");
        const end = @min(self.scroll_offset + self.visible_rows, self.items.len);
        for (self.items[self.scroll_offset..end], self.scroll_offset..) |item, i| {
            try render.drawListItem(
                writer,
                item.selected,
                i == self.cursor,
                item.deletable,
                item.status,
                item.label,
                cols,
            );
        }
    }
};
