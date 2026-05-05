# AI 共通ガイド

このドキュメントは、Claude Code、Codex、その他の AI エージェントが共通して参照する `ct` プロジェクトの作業ルールと仕様です。

## 概要

`ct` は Bash 製の Claude / Codex tools マネージャーです。`src/ct` が本体で、スキル・プラグインを集約元からプロジェクトまたはグローバル配置先へコピー管理します。

現在のバージョン: **0.1.0**（`ct version` で確認可能）

## 共通作業ルール

- 日本語で簡潔に報告する。
- 既存の Bash スタイルに合わせる。
- 外部入力は `validate_name` などで検証する。
- `.env`、秘密鍵、認証情報、token、credential などの内容は出力しない。
- 動作コードを削除する場合は理由を説明する。
- 依頼範囲外のリファクタリングはしない。
- 未追跡ファイルや他者の変更を勝手に削除・上書きしない。
- 変更前に対象ファイルと変更内容を説明する。
- 変更後は可能な範囲で構文チェック・テスト・差分確認を行う。

## 動作前提

- **Linux / WSL 専用**。`flock`（並行書き込み保護）および `date -Iseconds`（GNU date）に依存するため、macOS / BSD では動作しない。
- `rsync` が利用可能な場合は rsync でコピーし、なければ `cp` にフォールバックする。

## 構成

単一ファイル: `src/ct`（インストール先は PATH 上の任意の場所）

## 主な環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `CT_HOME` | `~/.claude-tools` | スキル・プラグインの集約元 |
| `GLOBAL_CLAUDE_DIR` | `~/.claude` | グローバルターゲットのベースパス |
| `CODEX_HOME` | `~/.codex` | Codex global plugin のベースパス |
| `GLOBAL_AGENTS_DIR` | `~/.agents` | Codex global skill / marketplace のベースパス |

## アーキテクチャ

```text
CT_HOME/
  skills/<name>/              ← git clone 先または手動配置
    .ct-include               ← （任意）コピー対象を列挙するフィルタファイル
  plugins/<name>/

.claude/
  skills/<name>/    ← Claude 用コピー先（.git, .ct-include は除外）
  plugins/<name>/
  .ct-manifest.json ← 管理台帳

.agents/
  skills/<name>/              ← Codex project/global skill コピー先
  plugins/marketplace.json    ← Codex plugin marketplace（ct-local）

plugins/<name>/               ← Codex project plugin コピー先
~/.codex/plugins/<name>/      ← Codex global plugin コピー先
```

## ターゲット

未指定時は `--target claude` と同じで、既存の Claude 用挙動を維持する。

`--target codex` を指定すると、Claude 用の `.claude/` ではなく Codex の公式配置にコピーする。

- skill project: `<project>/.agents/skills/<name>`
- skill global: `~/.agents/skills/<name>`
- plugin project: `<project>/plugins/<name>` と `<project>/.agents/plugins/marketplace.json`
- plugin global: `~/.codex/plugins/<name>` と `~/.agents/plugins/marketplace.json`

Codex plugin はコピー元の実効ルートに `.codex-plugin/plugin.json` が必要。`ct` が管理する marketplace は `name: "ct-local"` のみ更新し、既存の別 marketplace は上書きしない。

## コピー元の解決ルール

`add` / `sync` 時にコピー先へコピーする際、コピー元は以下の優先順位で決定される。

1. **`.ct-include` フィルタ**（有効パターンあり） → ルートからフィルタしてコピー
2. **サブディレクトリ自動検出** → `CT_HOME/<type>/<name>/<type>/<name>/` が存在すればそこをコピー元として使用
3. **ルート全コピー**（後方互換） → 上記いずれにも当てはまらなければ、`CT_HOME/<type>/<name>/` 全体をコピー

### サブディレクトリ自動検出

スキルやプラグインのリポジトリが `skills/<name>/`（type が skills の場合）または `plugins/<name>/`（type が plugins の場合）にコンテンツを格納しているケースに対応する。

例: `CT_HOME/skills/playwright-cli/skills/playwright-cli/SKILL.md` がある場合、コピー先では `SKILL.md` が直下に配置される（中間の `skills/playwright-cli/` ディレクトリは展開される）。

### `.ct-include` フィルタファイル

`CT_HOME/<type>/<name>/.ct-include` を配置すると、`add` / `sync` 時にそこで列挙したファイル・ディレクトリのみがコピーされる。

```text
# Claude Code に必要なファイルのみ
SKILL.md
references/
```

- 1 行 1 パターン、空行・`#` コメント行は無視する。
- 有効なパターンが 0 行の場合（空ファイル / コメントのみ）はファイル無しと同じ扱い。
- ディレクトリは末尾 `/` で指定する（例: `references/`）。
- **トップレベル名のみ** サポートする（`a/b/c.txt` のようなパス区切りパターンは未対応）。
- `.ct-include` 自体はコピー先に含まれない。

## `<name>` の命名規約

許容パターン: `^[A-Za-z0-9._-]+$`（英数字・ドット・アンダースコア・ハイフンのみ）

パストラバーサル防止のための制約。`../foo` のような入力は `invalid name` エラーで拒否される。

## マニフェスト形式

`<dest>/<type-dir>/.ct-manifest.json` に以下の形式で保存する。JSON パーサー不使用で、awk による行単位のパースを実装している。

```json
{
  "managed": {
    "some-skill": {"source": "/path/to/src", "copied_at": "2026-01-01T00:00:00+09:00", "git": true}
  }
}
```

**書き込み規約**（実装上の制約）:

- `source` フィールドの値は書き込み時に `\` → `\\`、`"` → `\"` をエスケープする。
- 改行を含む値は受け付けない（書き込み時に `die` で終了）。
- パーサ側は 1 行 1 エントリ前提のため、この不変条件を維持する。
- 並行書き込みは `flock` によりマニフェスト単位でロックして保護する。

## コマンドフロー

- `register` → `CT_HOME/<type>/<name>` へ `git clone`
- `add` → `CT_HOME` → ターゲットのコピー先へ配置し、マニフェスト更新（コピー元解決ルールに従う）
- `include` → `CT_HOME/<type>/<name>/.ct-include` のパターンを追加・削除・一覧表示
- `update` → `CT_HOME` 内の git リポジトリを `git pull --ff-only`（コピー先には反映されない）
- `sync` → `update` 済みのソースを再コピーしてマニフェスト更新（コピー元解決ルールに従う）
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

## 自動テスト

変更後は可能な範囲で以下を実行する。

```bash
bash -n src/ct
bats tests/security.bats
bats tests/ct-include.bats
bats tests/codex-target.bats
```

`bats` コマンドがない環境では、`tests/bats/bin/bats` などプロジェクト内の Bats を確認する。どちらも実行できない場合は、その旨を報告する。
