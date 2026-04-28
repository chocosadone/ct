# ct

`ct` は Claude Tools マネージャー。
`~/.claude-tools/` を集約元として、スキル・プラグインをプロジェクトまたはグローバルの `.claude/` ディレクトリにコピー管理する Bash スクリプト。

## 使い方

### Git 管理の skill を集約元に追加
ct register skill https://github.com/user/some-skill.git

### プロジェクトに追加（カレントディレクトリの .claude/）
ct add skill some-skill

### グローバルに追加
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