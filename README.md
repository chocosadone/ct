# ct

`ct` は Claude / Codex tools マネージャー。
`~/.claude-tools/` を集約元として、スキル・プラグインを Claude Code または Codex のプロジェクト / グローバル配置先へコピー管理する Bash スクリプト。

## 使い方

### Git 管理の skill を集約元に追加
ct register skill https://github.com/user/some-skill.git

### プロジェクトに追加（既定: カレントディレクトリの `.claude/`）
ct add skill some-skill

### グローバルに追加（既定: `~/.claude/`）
ct add skill some-skill --global

### 集約元の更新（git pull のみ、コピー先には反映されない）
ct update skill some-skill
ct update --all

### 更新内容をコピー先に反映
ct sync skill some-skill
ct sync skill some-skill --global

### 削除（確認プロンプトあり）
ct remove skill some-skill
ct remove skill some-skill -y    # 確認スキップ

### 一覧
ct list                                  # 集約元
ct list --installed                      # カレントプロジェクトの管理対象
ct list --installed --global             # グローバルの管理対象

### コピー対象のフィルタ管理（.ct-include）

git 管理のスキルリポジトリには `SKILL.md` 以外のファイル（README, CI 設定等）が含まれることがある。
`.ct-include` に列挙したファイル・ディレクトリだけをコピーするよう制限できる。

ct include skill some-skill add SKILL.md       # SKILL.md を対象に追加
ct include skill some-skill add 'references/'  # ディレクトリを対象に追加
ct include skill some-skill remove README.md   # 除外するパターンを削除
ct include skill some-skill                    # 現在のフィルタ一覧

### コピー元の自動検出

`.ct-include` がない場合、リポジトリ内に `skills/<name>/`（または plugin の場合 `plugins/<name>/`）が
存在すれば自動的にそこをコピー元として使用する。スキルの実体がサブディレクトリに格納されている
リポジトリ（例: `repo/skills/playwright-cli/SKILL.md`）に対してフィルタ設定なしで対応できる。

優先順位:
1. `.ct-include`（有効パターンあり）
2. `skills/<name>/` または `plugins/<name>/` サブディレクトリ
3. リポジトリルート全体

## Codex 対応

既定のターゲットは従来どおり Claude Code（`--target claude`）です。Codex 用に配置する場合は `--target codex` を付ける。

```bash
# プロジェクトスコープ: .agents/skills/<name>
ct add skill some-skill --target codex

# グローバルスコープ: ~/.agents/skills/<name>
ct add skill some-skill --target codex --global

# プロジェクトスコープ: plugins/<name> と .agents/plugins/marketplace.json
ct add plugin some-plugin --target codex

# グローバルスコープ: ~/.codex/plugins/<name> と ~/.agents/plugins/marketplace.json
ct add plugin some-plugin --target codex --global
```

Codex plugin は `.codex-plugin/plugin.json` が必要。`ct` が生成・更新する marketplace は `ct-local` という名前で管理される。既存の marketplace が `ct-local` でない場合、上書きを避けるためエラーになる。

Codex target の配置先は以下のとおり。

| 種別 | project | global |
|------|---------|--------|
| skill | `.agents/skills/<name>` | `~/.agents/skills/<name>` |
| plugin | `plugins/<name>` + `.agents/plugins/marketplace.json` | `~/.codex/plugins/<name>` + `~/.agents/plugins/marketplace.json` |

インストール済み一覧、同期、削除も target を指定できる。

```bash
ct list --installed --target codex
ct sync plugin some-plugin --target codex
ct remove plugin some-plugin --target codex -y
```
