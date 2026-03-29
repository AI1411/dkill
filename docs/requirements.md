# dkill — 設計ドキュメント

## コンセプト

Zig製のDocker リソース選択的クリーンアップTUI。停止コンテナ、danglingイメージ、未使用ボリューム・ネットワークをインタラクティブに一覧表示し、選択したものだけを削除する。`docker system prune` の「全部消すか何もしないか」問題を解決する。Docker CLI への依存なし（Unix Socket で Docker Engine API を直接叩く）。

### 既存ツールとの差別化

| ツール | 問題点 | dkill の優位性 |
|--------|--------|----------------|
| docker system prune | 全削除 or 何もしない、確認が雑 | TUI で選択的削除 |
| docker ps / images | 一覧と削除が別コマンド、パイプが面倒 | 一覧→選択→削除がワンフロー |
| lazydocker | 高機能だが重い (Go製, 30MB+) | <1MB、起動 <50ms |
| ctop | モニタリング特化、クリーンアップ弱い | クリーンアップ特化 |
| docker desktop | GUI必須、リモート非対応 | ターミナルで完結、SSH越し可 |

---

## アーキテクチャ

```
┌─────────────────────────────────────────────────────┐
│                    CLI Entry                        │
│  dkill [command] [options]                          │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│           Docker Engine API Client                  │
│           (Unix Socket: /var/run/docker.sock)       │
│                                                     │
│  HTTP/1.1 over Unix Domain Socket                   │
│  GET /containers/json                               │
│  GET /images/json                                   │
│  GET /volumes                                       │
│  GET /networks                                      │
│  GET /system/df          ← ディスク使用量            │
│  DELETE /containers/{id}                            │
│  DELETE /images/{id}                                │
│  DELETE /volumes/{name}                             │
│  POST /containers/{id}/stop                         │
└──────────────┬──────────────────────────────────────┘
               │
       ┌───────┼───────┬──────────┐
       ▼       ▼       ▼          ▼
┌────────┐┌────────┐┌────────┐┌────────┐
│Contai- ││Images  ││Volumes ││Networks│
│ners   ││        ││        ││        │
│Tab     ││Tab     ││Tab     ││Tab     │
└────────┘└────────┘└────────┘└────────┘
       │       │       │          │
       └───────┴───────┴──────────┘
               │
               ▼
       ┌──────────────┐
       │  TUI Render  │
       │  (4タブ構成)  │
       └──────────────┘
```

---

## TUI デザイン

### メイン画面

```
┌─ dkill ───────────────────────────────────────────────────────┐
│                                                               │
│  Disk Usage: 12.4 GB total  (3.2 GB reclaimable)             │
│                                                               │
│  [Containers]  [Images]  [Volumes]  [Networks]                │
│  ─────────────────────────────────────────────────────────    │
│                                                               │
│  ☐  STATUS     NAME                  IMAGE          SIZE      │
│  ─────────────────────────────────────────────────────────    │
│  ☑  Exited(0)  api-server-dev        my-api:latest  0 B      │
│  ☑  Exited(1)  postgres-test         postgres:16    45 MB     │
│  ☐  Exited(0)  redis-cache           redis:7        12 MB    │
│  ☑  Exited(137) worker-batch-3       worker:v2      0 B      │
│  ☐  Running    api-server-prod       my-api:latest  --       │
│  ☐  Running    postgres-main         postgres:16    --        │
│                                                               │
│  Selected: 3 containers (45 MB)                               │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ [Space] 選択  [a] 全選択  [A] 停止のみ全選択  [Tab] タブ切替 │
│ [d] 削除実行  [s] 停止→削除  [i] 詳細  [q] 終了  [/] 検索   │
└───────────────────────────────────────────────────────────────┘
```

### Images タブ

```
│  [Containers]  [Images]  [Volumes]  [Networks]                │
│  ─────────────────────────────────────────────────────────    │
│                                                               │
│  ☐  TAG                        ID           SIZE    CREATED   │
│  ─────────────────────────────────────────────────────────    │
│  ☑  <none>:<none>              a1b2c3d4     1.2 GB  3 days    │
│  ☑  <none>:<none>              e5f6g7h8     890 MB  5 days    │
│  ☐  my-api:latest              i9j0k1l2     245 MB  1 hour    │
│  ☐  my-api:v1.2.0              m3n4o5p6     245 MB  2 weeks   │
│  ☑  postgres:15                q7r8s9t0     420 MB  1 month   │
│  ☐  postgres:16                u1v2w3x4     430 MB  1 hour    │
│  ☐  redis:7                    y5z6a7b8     130 MB  2 weeks   │
│                                                               │
│  Selected: 3 images (2.5 GB reclaimable)                      │
│                                                               │
│  ⚠  Dangling images: 2 (2.1 GB) — Press 'D' to select all   │
```

### Volumes タブ

```
│  [Containers]  [Images]  [Volumes]  [Networks]                │
│  ─────────────────────────────────────────────────────────    │
│                                                               │
│  ☐  NAME                          SIZE     USED BY            │
│  ─────────────────────────────────────────────────────────    │
│  ☑  postgres_data_test            2.1 GB   (none)             │
│  ☐  postgres_data_main            4.5 GB   postgres-main      │
│  ☑  redis_data_old                56 MB    (none)             │
│  ☑  tmp_build_cache               890 MB   (none)             │
│  ☐  node_modules_cache            1.2 GB   api-server-dev     │
│                                                               │
│  Selected: 3 volumes (3.0 GB reclaimable)                     │
│  ⚠  Orphaned volumes: 3 (3.0 GB) — Press 'O' to select all  │
```

### 削除確認ダイアログ

```
┌─ 削除確認 ──────────────────────────────────────────┐
│                                                     │
│  以下を削除します:                                   │
│                                                     │
│    Containers:  3 個                                │
│    Images:      3 個  (2.5 GB)                      │
│    Volumes:     3 個  (3.0 GB)                      │
│    ────────────────────────────                     │
│    合計: 5.5 GB 解放予定                             │
│                                                     │
│  ⚠  ボリュームの削除は元に戻せません                  │
│                                                     │
│         [Enter] 実行    [Esc] キャンセル             │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 削除実行中

```
│  Deleting...                                                  │
│                                                               │
│  ✓ Container api-server-dev          removed                  │
│  ✓ Container postgres-test           removed                  │
│  ✓ Container worker-batch-3          removed                  │
│  ✓ Image     a1b2c3d4 (<none>)       removed     1.2 GB      │
│  ✓ Image     e5f6g7h8 (<none>)       removed     890 MB      │
│  ⠋ Image     q7r8s9t0 (postgres:15)  removing...             │
│  ○ Volume    postgres_data_test      pending                  │
│  ○ Volume    redis_data_old          pending                  │
│  ○ Volume    tmp_build_cache         pending                  │
│                                                               │
│  Progress: 5/9    Freed: 2.1 GB                               │
```

---

## CLI インターフェース

```bash
# TUI モード (デフォルト)
dkill

# 非インタラクティブ: 停止コンテナ一覧
dkill containers --exited

# 非インタラクティブ: dangling イメージ一覧
dkill images --dangling

# 非インタラクティブ: 孤立ボリューム一覧
dkill volumes --orphaned

# 一括削除 (CI用、確認プロンプトあり)
dkill prune --containers --images-dangling --volumes-orphaned
dkill prune --all --yes  # 確認スキップ

# ドライラン (何が消えるか表示のみ)
dkill prune --all --dry-run

# JSON 出力 (スクリプト連携)
dkill containers --exited --json
dkill images --dangling --json

# ディスク使用量サマリー
dkill df

# 出力例:
#  TYPE          TOTAL    ACTIVE   RECLAIMABLE
#  Containers    12       4        8 (234 MB)
#  Images        25       8        17 (8.2 GB)
#  Volumes       9        3        6 (4.1 GB)
#  Networks      7        2        5
#  Build Cache                     2.3 GB
#  ─────────────────────────────────────────
#  Total reclaimable: 14.8 GB

# Docker ソケットパス指定 (リモート/カスタム)
dkill --socket /path/to/docker.sock
dkill --host tcp://remote:2375

# フィルタ
dkill containers --created-before 7d    # 7日以上前に作成
dkill images --created-before 30d       # 30日以上前
dkill --label "env=staging"             # ラベルでフィルタ
```

---

## Docker Engine API 仕様

### Unix Socket 通信

```
ソケットパス: /var/run/docker.sock (デフォルト)
プロトコル: HTTP/1.1 over Unix Domain Socket
API バージョン: v1.45+
```

### 使用するエンドポイント

```
# リソース一覧取得
GET /v1.45/containers/json?all=true&size=true
GET /v1.45/images/json?all=true
GET /v1.45/volumes
GET /v1.45/networks
GET /v1.45/system/df

# コンテナ操作
POST /v1.45/containers/{id}/stop
DELETE /v1.45/containers/{id}?force=true

# イメージ操作
DELETE /v1.45/images/{id}?force=false&noprune=false

# ボリューム操作
DELETE /v1.45/volumes/{name}

# ネットワーク操作
DELETE /v1.45/networks/{id}

# レスポンスはすべて JSON
```

### レスポンス例 (containers/json)

```json
[
  {
    "Id": "abc123...",
    "Names": ["/api-server-dev"],
    "Image": "my-api:latest",
    "ImageID": "sha256:...",
    "State": "exited",
    "Status": "Exited (0) 3 hours ago",
    "Created": 1711700000,
    "SizeRw": 0,
    "SizeRootFs": 245000000,
    "Labels": { "env": "dev" },
    "Ports": [{ "PrivatePort": 8080, "PublicPort": 8080 }]
  }
]
```

---

## プロジェクト構成

```
dkill/
├── build.zig
├── build.zig.zon
├── README.md
│
├── src/
│   ├── main.zig                # CLI エントリ、サブコマンド分岐
│   │
│   ├── docker/
│   │   ├── client.zig          # Unix Socket HTTP クライアント
│   │   ├── api.zig             # Docker API ラッパー
│   │   ├── containers.zig      # コンテナ操作
│   │   ├── images.zig          # イメージ操作
│   │   ├── volumes.zig         # ボリューム操作
│   │   ├── networks.zig        # ネットワーク操作
│   │   ├── system.zig          # system/df (ディスク使用量)
│   │   └── types.zig           # Container, Image, Volume 型定義
│   │
│   ├── tui/
│   │   ├── app.zig             # TUI アプリケーション状態管理
│   │   ├── render.zig          # 描画エンジン
│   │   ├── tabs.zig            # タブ切り替えロジック
│   │   ├── list.zig            # チェックボックス付きリスト
│   │   ├── dialog.zig          # 確認ダイアログ
│   │   ├── progress.zig        # 削除プログレス表示
│   │   ├── search.zig          # インクリメンタルサーチ
│   │   └── input.zig           # キーボード入力ハンドラ
│   │
│   ├── filter/
│   │   ├── age.zig             # 作成日時フィルタ
│   │   ├── label.zig           # ラベルフィルタ
│   │   ├── status.zig          # ステータスフィルタ
│   │   └── dependency.zig      # 依存関係チェック (使用中判定)
│   │
│   ├── output/
│   │   ├── table.zig           # 非TUI テーブル出力
│   │   ├── json.zig            # JSON 出力
│   │   └── summary.zig         # df サマリー出力
│   │
│   └── utils/
│       ├── socket.zig          # Unix Domain Socket ヘルパー
│       ├── http.zig            # 最小 HTTP/1.1 パーサー
│       ├── json_parse.zig      # JSON パーサー (std.json ラッパー)
│       ├── size.zig            # バイト数 → 人間可読変換
│       ├── time.zig            # "3 days ago" 相対時間表示
│       └── color.zig           # ANSI カラー
│
└── tests/
    ├── api_test.zig
    └── fixtures/
        ├── containers.json     # テスト用レスポンス
        └── images.json
```

---

## 実装フェーズ

### Phase 1: Docker API クライアント + 一覧表示 (Week 1)

```
目標: dkill containers --exited で停止コンテナが表示される

タスク:
  [1] Unix Domain Socket HTTP クライアント
  [2] Docker API レスポンス JSON パース
  [3] コンテナ一覧取得 + テーブル表示
  [4] イメージ一覧取得 + テーブル表示
  [5] ボリューム一覧取得 + テーブル表示
  [6] system/df でディスク使用量取得
  [7] --json 出力
```

### Phase 2: TUI 基盤 (Week 2)

```
目標: dkill で TUI が起動し、4タブでリソース一覧が見える

タスク:
  [1] Raw terminal mode 設定
  [2] タブ切り替え UI
  [3] チェックボックス付きリスト描画
  [4] j/k でカーソル移動、Space で選択
  [5] 選択数・サイズのリアルタイム集計表示
  [6] / キーでインクリメンタルサーチ
```

### Phase 3: 削除操作 + 確認 (Week 3)

```
目標: TUI で選択→削除確認→実行→結果表示が動く

タスク:
  [1] 削除確認ダイアログ
  [2] 削除実行 (並列 DELETE リクエスト)
  [3] プログレス表示 (✓/✗/⠋ アニメーション)
  [4] エラーハンドリング (使用中イメージ等)
  [5] 一括選択ショートカット (a, A, D, O)
  [6] 非TUIモード prune サブコマンド
  [7] --dry-run 対応
```

### Phase 4: フィルタ + 仕上げ (Week 4)

```
目標: --created-before, --label フィルタ、README 完成

タスク:
  [1] 作成日時フィルタ (7d, 30d, 90d)
  [2] ラベルフィルタ
  [3] ネットワークタブ実装
  [4] 依存関係の可視化 (コンテナ→イメージ→ボリューム)
  [5] --host tcp:// 対応 (リモート Docker)
  [6] README / スクリーンショット / デモ GIF
```

---

## Zig の特性が活きるポイント

### 1. Unix Domain Socket を直接操作

```zig
// Docker CLI を経由せず、ソケットで直接通信
const socket = try std.net.connectUnixSocket("/var/run/docker.sock");
defer socket.close();

const request =
    "GET /v1.45/containers/json?all=true HTTP/1.1\r\n" ++
    "Host: localhost\r\n" ++
    "Connection: close\r\n\r\n";

try socket.writeAll(request);
// レスポンスを直接パース — docker CLI のプロセス起動コストゼロ
```

### 2. comptime でAPI パスを型安全に構築

```zig
fn deleteContainer(comptime version: []const u8, id: []const u8) !void {
    // API バージョンをコンパイル時に埋め込み
    const path = comptime "/v" ++ version ++ "/containers/";
    const full_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ path, id });
    // ...
}
```

### 3. サイズ表示のコンパイル時テーブル

```zig
const size_units = comptime [_]struct { threshold: u64, unit: []const u8 }{
    .{ .threshold = 1 << 30, .unit = "GB" },
    .{ .threshold = 1 << 20, .unit = "MB" },
    .{ .threshold = 1 << 10, .unit = "KB" },
    .{ .threshold = 0,       .unit = "B"  },
};

fn humanSize(bytes: u64) struct { value: f64, unit: []const u8 } {
    inline for (size_units) |u| {
        if (bytes >= u.threshold) return .{
            .value = @as(f64, @floatFromInt(bytes)) / @as(f64, @floatFromInt(u.threshold)),
            .unit = u.unit,
        };
    }
    return .{ .value = @as(f64, @floatFromInt(bytes)), .unit = "B" };
}
```

---

## 安全設計

### 削除保護

1. **Running コンテナは削除不可**: 明示的な停止操作が必要 (`s` キー = stop → delete)
2. **使用中ボリュームは警告**: コンテナが参照しているボリュームは ⚠ マーク
3. **確認ダイアログ必須**: `--yes` フラグなしでは必ず確認
4. **ドライラン**: `--dry-run` で削除対象のみ表示

### エラー処理

1. Docker ソケット接続失敗 → 明確なエラーメッセージ + 権限チェック案内
2. API レスポンスエラー → リトライ or スキップ + ユーザー通知
3. 削除中のエラー → 個別表示、残りは続行

---

## 成功指標

1. **起動時間**: < 50ms (Docker API 呼び出し含む)
2. **バイナリサイズ**: < 1MB
3. **依存**: Docker CLI 不要、ソケット通信のみ
4. **操作性**: TUI 起動→選択→削除完了が 10秒以内
5. **安全性**: 意図しない削除ゼロ (確認必須、Running 保護)