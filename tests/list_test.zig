const std = @import("std");
const list_mod = @import("../src/tui/list.zig");

const SelectableItem = list_mod.SelectableItem;
const List = list_mod.List;

fn makeItem(id: []const u8, label: []const u8, deletable: bool) SelectableItem {
    return SelectableItem{
        .id = id,
        .label = label,
        .deletable = deletable,
        .selected = false,
    };
}

// ─── moveDown ────────────────────────────────────────────────

test "moveDown advances cursor" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
        makeItem("b", "beta", true),
        makeItem("c", "gamma", true),
    };
    var lst = List.init(&items, 10);
    lst.moveDown();
    try std.testing.expectEqual(@as(usize, 1), lst.cursor);
}

test "moveDown does not exceed last item" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
    };
    var lst = List.init(&items, 10);
    lst.moveDown();
    try std.testing.expectEqual(@as(usize, 0), lst.cursor);
}

// ─── moveUp ──────────────────────────────────────────────────

test "moveUp moves cursor back" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
        makeItem("b", "beta", true),
    };
    var lst = List.init(&items, 10);
    lst.cursor = 1;
    lst.moveUp();
    try std.testing.expectEqual(@as(usize, 0), lst.cursor);
}

test "moveUp does not go below 0" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
    };
    var lst = List.init(&items, 10);
    lst.moveUp();
    try std.testing.expectEqual(@as(usize, 0), lst.cursor);
}

// ─── toggleCurrent ───────────────────────────────────────────

test "toggleCurrent selects deletable item" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
    };
    var lst = List.init(&items, 10);
    lst.toggleCurrent();
    try std.testing.expect(lst.items[0].selected);
}

test "toggleCurrent deselects selected item" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
    };
    items[0].selected = true;
    var lst = List.init(&items, 10);
    lst.toggleCurrent();
    try std.testing.expect(!lst.items[0].selected);
}

test "toggleCurrent does not select non-deletable item" {
    var items = [_]SelectableItem{
        makeItem("r", "running-container", false),
    };
    var lst = List.init(&items, 10);
    lst.toggleCurrent();
    try std.testing.expect(!lst.items[0].selected);
}

// ─── selectAll / deselectAll ─────────────────────────────────

test "selectAll selects all deletable items" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
        makeItem("b", "beta", false),
        makeItem("c", "gamma", true),
    };
    var lst = List.init(&items, 10);
    lst.selectAll();
    try std.testing.expect(lst.items[0].selected);
    try std.testing.expect(!lst.items[1].selected); // non-deletable
    try std.testing.expect(lst.items[2].selected);
}

test "deselectAll clears all selections" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
        makeItem("c", "gamma", true),
    };
    items[0].selected = true;
    items[1].selected = true;
    var lst = List.init(&items, 10);
    lst.deselectAll();
    try std.testing.expect(!lst.items[0].selected);
    try std.testing.expect(!lst.items[1].selected);
}

// ─── selectedCount ───────────────────────────────────────────

test "selectedCount returns correct count" {
    var items = [_]SelectableItem{
        makeItem("a", "alpha", true),
        makeItem("b", "beta", true),
        makeItem("c", "gamma", true),
    };
    items[0].selected = true;
    items[2].selected = true;
    var lst = List.init(&items, 10);
    try std.testing.expectEqual(@as(usize, 2), lst.selectedCount());
}

// ─── scroll offset ───────────────────────────────────────────

test "scroll offset advances when cursor moves past visible rows" {
    var items = [_]SelectableItem{
        makeItem("a", "1", true),
        makeItem("b", "2", true),
        makeItem("c", "3", true),
        makeItem("d", "4", true),
        makeItem("e", "5", true),
    };
    // visible_rows = 3
    var lst = List.init(&items, 3);
    lst.moveDown(); // cursor=1
    lst.moveDown(); // cursor=2
    lst.moveDown(); // cursor=3, should scroll
    try std.testing.expectEqual(@as(usize, 3), lst.cursor);
    try std.testing.expect(lst.scroll_offset > 0);
}

test "scroll offset decreases when cursor moves above visible area" {
    var items = [_]SelectableItem{
        makeItem("a", "1", true),
        makeItem("b", "2", true),
        makeItem("c", "3", true),
        makeItem("d", "4", true),
    };
    var lst = List.init(&items, 2);
    lst.cursor = 3;
    lst.scroll_offset = 2;
    lst.moveUp(); // cursor=2, scroll_offset may decrease
    lst.moveUp(); // cursor=1
    try std.testing.expect(lst.scroll_offset <= lst.cursor);
}
