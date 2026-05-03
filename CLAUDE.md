# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

`ct` は Claude Tools マネージャー。`~/.claude-tools/` を集約元として、スキル・プラグインをプロジェクトまたはグローバルの `.claude/` ディレクトリにコピー管理する Bash スクリプト。

現在のバージョン: **0.1.0**（`ct version` で確認可能）

## 動作前提

- **Linux / WSL 専用**。`flock`（並行書き込み保護）および `date -Iseconds`（GNU date）に依存するため、macOS / BSD では動作しない
- `rsync` が利用可能な場合は rsync でコピー、なければ `cp` にフォールバックする

## 構成

単一ファイル: `src/ct`（インストール先は PATH 上の任意の場所）

## 主な環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `CT_HOME` | `~/.claude-tools` | スキル・プラグインの集約元 |
| `GLOBAL_CLAUDE_DIR` | `~/.claude` | グローバルターゲットのベースパス |

## アーキテクチャ

```
CT_HOME/
  skills/<name>/              ← git clone 先または手動配置
    .ct-include               ← （任意）コピー対象を列挙するフィルタファイル
  plugins/<name>/

.claude/
  skills/<name>/    ← コピー先（.git, .ct-include は除外）
  plugins/<name>/
  .ct-manifest.json ← 管理台帳
```

### `.ct-include` フィルタファイル

`CT_HOME/<type>/<name>/.ct-include` を配置すると、`add` / `sync` 時にそこで列挙したファイル・ディレクトリのみがコピーされる。ファイルが存在しない場合は従来通り全ファイルをコピーする（後方互換）。

```
# Claude Code に必要なファイルのみ
SKILL.md
references/
```

- 1 行 1 パターン、空行・`#` コメント行は無視
- ディレクトリは末尾 `/` で指定（例: `references/`）
- `.ct-include` 自体はコピー先に含まれない

### `<name>` の命名規約

許容パターン: `^[A-Za-z0-9._-]+$`（英数字・ドット・アンダースコア・ハイフンのみ）

パストラバーサル防止のための制約。`../foo` のような入力は `invalid name` エラーで拒否される。

### マニフェスト形式

`<dest>/<type-dir>/.ct-manifest.json` に以下の形式で保存する。
JSON パーサー不使用で、awk による行単位のパースを実装している。

```json
{
  "managed": {
    "some-skill": {"source": "/path/to/src", "copied_at": "2026-01-01T00:00:00+09:00", "git": true}
  }
}
```

**書き込み規約**（実装上の制約）:
- `source` フィールドの値は書き込み時に `\` → `\\`、`"` → `\"` をエスケープする
- 改行を含む値は受け付けない（書き込み時に `die` で終了）
- パーサ側は 1 行 1 エントリ前提のため、この不変条件を維持する
- 並行書き込みは `flock` によりマニフェスト単位でロックして保護する

### コマンドフロー

- `register` → `CT_HOME/<type>/<name>` へ `git clone`
- `add` → `CT_HOME` → `.claude/<type>/` へ rsync し、マニフェスト更新（`.ct-include` があればフィルタ適用）
- `include` → `CT_HOME/<type>/<name>/.ct-include` のパターンを追加・削除・一覧表示
- `update` → `CT_HOME` 内の git リポジトリを `git pull --ff-only`（コピー先には反映されない）
- `sync` → `update` 済みのソースを再コピーしてマニフェスト更新（`.ct-include` があればフィルタ適用）
- `remove` → コピー先ディレクトリを削除しマニフェストから除去

## 手動テスト手順

```bash
# 構文チェック
bash -n src/ct

# バージョン表示
bash src/ct version

# ヘルプ表示
bash src/ct help

# ソース一覧（CT_HOME が存在すれば）
bash src/ct list

# インストール済み一覧（プロジェクトスコープ）
bash src/ct list --installed

# グローバルスコープ
bash src/ct list --installed --global

# .ct-include フィルタ管理（手動確認）
bash src/ct include skill <name>                    # → .ct-include なしのメッセージ
bash src/ct include skill <name> add SKILL.md       # → 追加成功
bash src/ct include skill <name> add 'references/'  # → 追加成功
bash src/ct include skill <name>                    # → SKILL.md と references/ が表示される
bash src/ct include skill <name> remove SKILL.md    # → 削除成功

# 不正な name でのエラー確認（T2 検証）
bash src/ct add skill '../foo'        # → "invalid name" で終了すること

# 特殊文字を含む CT_HOME でのマニフェスト整合性（T3 検証）
# CT_HOME="/tmp/space and quote\"" bash src/ct add ...
# → add 後のマニフェストが壊れていないこと

# 並行実行でのマニフェスト健全性（T4 検証）
# 2 プロセスから同時に ct add / ct sync を実行してもマニフェストが破損しないこと
```

自動テストは以下で実行できる。

```bash
# セキュリティ強化の受け入れテスト
bats tests/security.bats

# .ct-include フィルタリングおよび ct include コマンドのテスト
bats tests/ct-include.bats
```

変更後は上記自動テストに加えて、実際の add/remove/sync を手動で確認する。
