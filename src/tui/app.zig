const std = @import("std");
const api = @import("../docker/api.zig");
const types = @import("../docker/types.zig");
const size_util = @import("../utils/size.zig");
const list_mod = @import("list.zig");
const render = @import("render.zig");
const input = @import("input.zig");

/// TUI のモード。
pub const AppMode = enum {
    normal,
    confirm_delete,
    deleting,
    search,
};

/// タブ。
pub const Tab = enum {
    containers,
    images,
    volumes,
};

/// アプリケーション状態。
pub const App = struct {
    allocator: std.mem.Allocator,
    socket_path: []const u8,
    mode: AppMode,
    current_tab: Tab,

    // 各タブのアイテムスライス（loadData で確保）
    container_items: []list_mod.SelectableItem,
    image_items: []list_mod.SelectableItem,
    volume_items: []list_mod.SelectableItem,

    // 各タブのラベル文字列（freeLists で解放）
    container_labels: [][]u8,
    image_labels: [][]u8,
    volume_labels: [][]u8,

    // Docker リソース（freeLists で解放）
    containers: []types.Container,
    images: []types.Image,
    volumes: []types.Volume,

    // リストウィジェット（visible_rows は draw 時に更新）
    container_list: list_mod.List,
    image_list: list_mod.List,
    volume_list: list_mod.List,

    quit: bool,

    pub fn init(allocator: std.mem.Allocator, socket_path: []const u8) App {
        return App{
            .allocator = allocator,
            .socket_path = socket_path,
            .mode = .normal,
            .current_tab = .containers,
            .container_items = &[_]list_mod.SelectableItem{},
            .image_items = &[_]list_mod.SelectableItem{},
            .volume_items = &[_]list_mod.SelectableItem{},
            .container_labels = &[_][]u8{},
            .image_labels = &[_][]u8{},
            .volume_labels = &[_][]u8{},
            .containers = &[_]types.Container{},
            .images = &[_]types.Image{},
            .volumes = &[_]types.Volume{},
            .container_list = list_mod.List.init(&[_]list_mod.SelectableItem{}, 20),
            .image_list = list_mod.List.init(&[_]list_mod.SelectableItem{}, 20),
            .volume_list = list_mod.List.init(&[_]list_mod.SelectableItem{}, 20),
            .quit = false,
        };
    }

    pub fn deinit(self: *App) void {
        self.freeLists();
    }

    /// Docker API からデータを取得してリストを構築する。
    pub fn loadData(self: *App) !void {
        self.freeLists();

        var docker = api.DockerApi.init(self.allocator, self.socket_path);

        // コンテナ
        self.containers = try docker.listContainers();
        self.container_items = try self.allocator.alloc(list_mod.SelectableItem, self.containers.len);
        self.container_labels = try self.allocator.alloc([]u8, self.containers.len);
        for (self.containers, 0..) |c, i| {
            const name = if (c.Names.len > 0) c.Names[0] else "(no name)";
            const label = try std.fmt.allocPrint(
                self.allocator,
                "{s:<16}{s:<32}{s:<12}{s}",
                .{ c.shortId(), name, c.State, c.Image },
            );
            self.container_labels[i] = label;
            self.container_items[i] = .{
                .id = c.Id,
                .label = label,
                .deletable = !c.isRunning(),
                .selected = false,
            };
        }
        self.container_list = list_mod.List.init(self.container_items, 20);

        // イメージ
        self.images = try docker.listImages();
        self.image_items = try self.allocator.alloc(list_mod.SelectableItem, self.images.len);
        self.image_labels = try self.allocator.alloc([]u8, self.images.len);
        for (self.images, 0..) |img, i| {
            var size_buf: [16]u8 = undefined;
            const size_str = size_util.humanReadable(img.Size, &size_buf);
            const label = try std.fmt.allocPrint(
                self.allocator,
                "{s:<16}{s:<32}{s}",
                .{ img.Id[0..@min(img.Id.len, 12)], img.displayTag(), size_str },
            );
            self.image_labels[i] = label;
            self.image_items[i] = .{
                .id = img.Id,
                .label = label,
                .deletable = true,
                .selected = false,
            };
        }
        self.image_list = list_mod.List.init(self.image_items, 20);

        // ボリューム
        self.volumes = try docker.listVolumes();
        self.volume_items = try self.allocator.alloc(list_mod.SelectableItem, self.volumes.len);
        self.volume_labels = try self.allocator.alloc([]u8, self.volumes.len);
        for (self.volumes, 0..) |v, i| {
            const label = try std.fmt.allocPrint(
                self.allocator,
                "{s:<32}{s}",
                .{ v.Name, v.Driver },
            );
            self.volume_labels[i] = label;
            self.volume_items[i] = .{
                .id = v.Name,
                .label = label,
                .deletable = v.isOrphaned(),
                .selected = false,
            };
        }
        self.volume_list = list_mod.List.init(self.volume_items, 20);
    }

    fn freeLists(self: *App) void {
        for (self.container_labels) |lbl| self.allocator.free(lbl);
        self.allocator.free(self.container_labels);
        self.allocator.free(self.container_items);
        for (self.containers) |c| {
            self.allocator.free(c.Id);
            self.allocator.free(c.Image);
            self.allocator.free(c.State);
            self.allocator.free(c.Status);
            for (c.Names) |name| self.allocator.free(name);
            self.allocator.free(c.Names);
        }
        self.allocator.free(self.containers);

        for (self.image_labels) |lbl| self.allocator.free(lbl);
        self.allocator.free(self.image_labels);
        self.allocator.free(self.image_items);
        for (self.images) |img| {
            self.allocator.free(img.Id);
            for (img.RepoTags) |tag| self.allocator.free(tag);
            self.allocator.free(img.RepoTags);
        }
        self.allocator.free(self.images);

        for (self.volume_labels) |lbl| self.allocator.free(lbl);
        self.allocator.free(self.volume_labels);
        self.allocator.free(self.volume_items);
        for (self.volumes) |v| {
            self.allocator.free(v.Name);
            self.allocator.free(v.Driver);
            self.allocator.free(v.Mountpoint);
        }
        self.allocator.free(self.volumes);

        self.container_items = &[_]list_mod.SelectableItem{};
        self.image_items = &[_]list_mod.SelectableItem{};
        self.volume_items = &[_]list_mod.SelectableItem{};
        self.container_labels = &[_][]u8{};
        self.image_labels = &[_][]u8{};
        self.volume_labels = &[_][]u8{};
        self.containers = &[_]types.Container{};
        self.images = &[_]types.Image{};
        self.volumes = &[_]types.Volume{};
    }

    /// キー入力を処理する。
    pub fn handleKey(self: *App, key: input.Key) void {
        switch (self.mode) {
            .normal => self.handleNormalKey(key),
            .confirm_delete => self.handleConfirmKey(key),
            .deleting => {},
            .search => {},
        }
    }

    fn handleNormalKey(self: *App, key: input.Key) void {
        switch (key) {
            .char => |c| switch (c) {
                'j' => self.currentList().moveDown(),
                'k' => self.currentList().moveUp(),
                'a' => self.currentList().selectAll(),
                'd' => {
                    if (self.currentList().selectedCount() > 0) {
                        self.mode = .confirm_delete;
                    }
                },
                'q' => self.quit = true,
                else => {},
            },
            .space => self.currentList().toggleCurrent(),
            .tab => {
                self.current_tab = switch (self.current_tab) {
                    .containers => .images,
                    .images => .volumes,
                    .volumes => .containers,
                };
            },
            .ctrl_c, .ctrl_d => self.quit = true,
            .arrow_up => self.currentList().moveUp(),
            .arrow_down => self.currentList().moveDown(),
            else => {},
        }
    }

    fn handleConfirmKey(self: *App, key: input.Key) void {
        switch (key) {
            .enter => self.mode = .deleting,
            .escape => self.mode = .normal,
            .char => self.mode = .normal,
            else => self.mode = .normal,
        }
    }

    /// 現在タブのリストウィジェットへの参照を返す。
    pub fn currentList(self: *App) *list_mod.List {
        return switch (self.current_tab) {
            .containers => &self.container_list,
            .images => &self.image_list,
            .volumes => &self.volume_list,
        };
    }

    /// 終了すべきかどうかを返す。
    pub fn shouldQuit(self: *const App) bool {
        return self.quit;
    }

    /// 画面を描画する。
    pub fn draw(self: *App) !void {
        const stdout_file = std.fs.File.stdout();
        var buf: [65536]u8 = undefined;
        var writer = stdout_file.writer(&buf);
        const w = &writer.interface;

        // terminal サイズを取得（失敗時はデフォルト値）
        const size = input.getTerminalSize() catch input.TerminalSize{ .cols = 80, .rows = 24 };
        const cols = size.cols;
        const rows = size.rows;

        // visible_rows を更新（タブバー1行 + ステータス1行 + ヘルプ1行 = 3行）
        const list_rows = if (rows > 4) rows - 4 else 1;
        self.container_list.visible_rows = list_rows;
        self.image_list.visible_rows = list_rows;
        self.volume_list.visible_rows = list_rows;

        try render.clearAndHome(w);

        // タブバー
        const tab_names = [_][]const u8{ "Containers", "Images", "Volumes" };
        const active_idx: usize = switch (self.current_tab) {
            .containers => 0,
            .images => 1,
            .volumes => 2,
        };
        try render.drawTabBar(w, &tab_names, active_idx, cols);

        // リスト
        try self.currentList().draw(w, cols);

        // ステータスバー
        const lst = self.currentList();
        const count = lst.selectedCount();
        var status_buf: [64]u8 = undefined;
        const status_text = std.fmt.bufPrint(&status_buf, "{d} selected", .{count}) catch "?";
        try render.drawStatusBar(w, status_text, cols);

        // ヘルプバー
        try render.drawHelpBar(w, cols);

        // 確認ダイアログ
        if (self.mode == .confirm_delete) {
            try render.drawConfirmDialog(w, count, "?", rows, cols);
        }

        try writer.interface.flush();
    }
};
