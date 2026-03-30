# dk

Docker リソースをインタラクティブに管理する TUI ツール。
コンテナ・イメージ・ボリュームの一覧表示と削除を高速に行えます。

## 特徴

- **インタラクティブ TUI** — カラー表示のチェックボックス付きリストで複数リソースを選択して一括削除
- **CLI サブコマンド** — スクリプトやパイプラインから利用可能なコマンドライン操作
- **軽量・高速** — Zig 製のシングルバイナリ、バイナリサイズ 1MB 未満
- **並列取得** — コンテナ・イメージ・ボリュームを並列に取得して高速起動

## インストール

```sh
git clone https://github.com/AI1411/dkill.git
cd dkill
zig build -Doptimize=ReleaseSmall
sudo cp zig-out/bin/dk /usr/local/bin/
```

## 使い方

### TUI モード（引数なし）

```sh
dk
```

| キー | 操作 |
|------|------|
| `j` / `k` | カーソル移動 |
| `↑` / `↓` | カーソル移動 |
| `Space` | 選択 / 選択解除 |
| `a` | 削除可能な全アイテムを選択 |
| `Tab` | タブ切り替え（Containers / Images / Volumes） |
| `d` | 選択アイテムを削除 |
| `q` / `Ctrl-C` | 終了 |

### CLI サブコマンド

```sh
# コンテナ一覧
dk containers
dk containers --exited          # 停止コンテナのみ
dk containers --json            # JSON 出力

# イメージ一覧
dk images
dk images --dangling            # dangling イメージのみ
dk images --json

# ボリューム一覧
dk volumes
dk volumes --orphaned           # 孤立ボリュームのみ
dk volumes --json

# ディスク使用量サマリー
dk df

# 未使用リソースを一括削除
dk prune --all                  # 全未使用リソース
dk prune --containers           # 停止コンテナのみ
dk prune --images-dangling      # dangling イメージのみ
dk prune --volumes-orphaned     # 孤立ボリュームのみ
dk prune --all --yes            # 確認スキップ
dk prune --all --dry-run        # 削除対象を表示のみ（実削除なし）
```

## ビルド要件

- [Zig](https://ziglang.org/) 0.15.2 以上
- Docker が `/var/run/docker.sock` で稼働していること

## 開発

```sh
# ビルド
zig build

# テスト（Docker 不要）
SKIP_DOCKER_TESTS=1 zig build test

# テスト（Docker あり）
zig build test
```
