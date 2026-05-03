#!/usr/bin/env bats
# .ct-include フィルタリングおよび ct include コマンドのテスト

CT="$BATS_TEST_DIRNAME/../src/ct"

# ---------- セットアップ ----------

setup() {
  TEST_DIR="$(mktemp -d)"
  CT_HOME="$TEST_DIR/ct-home"
  PROJECT_DIR="$TEST_DIR/project"
  mkdir -p "$CT_HOME/skills" "$PROJECT_DIR"

  # テスト用スキル: 必要ファイルと不要ファイルを両方含む
  mkdir -p "$CT_HOME/skills/my-skill/references"
  echo "# skill" > "$CT_HOME/skills/my-skill/SKILL.md"
  echo "ref"     > "$CT_HOME/skills/my-skill/references/ref.md"
  echo "readme"  > "$CT_HOME/skills/my-skill/README.md"
  mkdir -p "$CT_HOME/skills/my-skill/tests"
  echo "test"    > "$CT_HOME/skills/my-skill/tests/test.sh"

  export CT_HOME PROJECT_DIR
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ---------- .ct-include なし: 後方互換 ----------

@test ".ct-include なし: 全ファイルがコピーされる" {
  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/tests/test.sh" ]
}

# ---------- .ct-include あり: フィルタリング ----------

@test ".ct-include あり: 列挙ファイルのみコピーされる" {
  printf 'SKILL.md\n' > "$CT_HOME/skills/my-skill/.ct-include"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
  [ ! -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]
  [ ! -d "$PROJECT_DIR/.claude/skills/my-skill/tests" ]
}

@test ".ct-include あり: ディレクトリ指定で中身ごとコピーされる" {
  printf 'SKILL.md\nreferences/\n' > "$CT_HOME/skills/my-skill/.ct-include"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/references/ref.md" ]
  [ ! -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]
  [ ! -d "$PROJECT_DIR/.claude/skills/my-skill/tests" ]
}

@test ".ct-include: コメント行・空行は無視される" {
  printf '# comment\n\nSKILL.md\n' > "$CT_HOME/skills/my-skill/.ct-include"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
  [ ! -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]
}

@test ".ct-include 自体はコピーされない" {
  printf 'SKILL.md\n' > "$CT_HOME/skills/my-skill/.ct-include"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/.claude/skills/my-skill/.ct-include" ]
}

# ---------- ct sync でも .ct-include が適用される ----------

@test "sync: .ct-include が適用される" {
  # .ct-include なしで add (全コピー)
  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]

  # .ct-include を追加して sync
  printf 'SKILL.md\nreferences/\n' > "$CT_HOME/skills/my-skill/.ct-include"
  run bash "$CT" sync skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
  [ ! -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]
}

# ---------- ct include コマンド ----------

@test "ct include list: .ct-include がない場合はメッセージを表示" {
  run bash "$CT" include skill my-skill
  [ "$status" -eq 0 ]
  [[ "$output" == *"no .ct-include"* ]]
}

@test "ct include add: パターンを追加できる" {
  run bash "$CT" include skill my-skill add SKILL.md
  [ "$status" -eq 0 ]
  grep -qxF 'SKILL.md' "$CT_HOME/skills/my-skill/.ct-include"
}

@test "ct include add: 重複追加はスキップされる" {
  bash "$CT" include skill my-skill add SKILL.md
  run bash "$CT" include skill my-skill add SKILL.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"already in .ct-include"* ]]
  [ "$(grep -cxF 'SKILL.md' "$CT_HOME/skills/my-skill/.ct-include")" -eq 1 ]
}

@test "ct include remove: パターンを削除できる" {
  printf 'SKILL.md\nreferences/\n' > "$CT_HOME/skills/my-skill/.ct-include"

  run bash "$CT" include skill my-skill remove SKILL.md
  [ "$status" -eq 0 ]
  ! grep -qxF 'SKILL.md' "$CT_HOME/skills/my-skill/.ct-include"
  grep -qxF 'references/' "$CT_HOME/skills/my-skill/.ct-include"
}

@test "ct include remove: .ct-include がない場合はエラー" {
  run bash "$CT" include skill my-skill remove SKILL.md
  [ "$status" -ne 0 ]
  [[ "$output" == *".ct-include not found"* ]]
}

@test "ct include list: 追加したパターンが表示される" {
  bash "$CT" include skill my-skill add SKILL.md
  bash "$CT" include skill my-skill add 'references/'

  run bash "$CT" include skill my-skill
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKILL.md"* ]]
  [[ "$output" == *"references/"* ]]
}

@test "ct include: 不正なアクションはエラー" {
  run bash "$CT" include skill my-skill bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown action"* ]]
}

@test "ct include: 存在しないスキルはエラー" {
  run bash "$CT" include skill no-such-skill
  [ "$status" -ne 0 ]
  [[ "$output" == *"source not found"* ]]
}

# ---------- skills/{name}/ サブディレクトリ自動検出 ----------

@test "サブディレクトリ自動検出: skills/<name>/ があれば直下にコピーされる" {
  # ソースリポジトリが skills/my-skill/ にスキルを持つ構造を作成
  mkdir -p "$CT_HOME/skills/my-skill/skills/my-skill/references"
  echo "# skill" > "$CT_HOME/skills/my-skill/skills/my-skill/SKILL.md"
  echo "ref"     > "$CT_HOME/skills/my-skill/skills/my-skill/references/ref.md"
  # 他のファイルはルートにある（コピーされないはず）
  echo "readme"  > "$CT_HOME/skills/my-skill/README.md"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/references/ref.md" ]
  [ ! -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]
  [ ! -d "$PROJECT_DIR/.claude/skills/my-skill/skills" ]
}

@test "サブディレクトリ自動検出: .ct-include があれば自動検出より優先される" {
  mkdir -p "$CT_HOME/skills/my-skill/skills/my-skill"
  echo "# skill" > "$CT_HOME/skills/my-skill/skills/my-skill/SKILL.md"
  # .ct-include で README.md だけを指定（自動検出より優先）
  printf 'README.md\n' > "$CT_HOME/skills/my-skill/.ct-include"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]
  [ ! -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
}

@test "sync: サブディレクトリ自動検出が適用される" {
  mkdir -p "$CT_HOME/skills/my-skill/skills/my-skill"
  echo "# skill" > "$CT_HOME/skills/my-skill/skills/my-skill/SKILL.md"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]

  echo "# updated" > "$CT_HOME/skills/my-skill/skills/my-skill/SKILL.md"
  run bash "$CT" sync skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  grep -q "updated" "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md"
}

@test "サブディレクトリ自動検出: plugin 型でも plugins/<name>/ が検出される" {
  mkdir -p "$CT_HOME/plugins/my-plugin/plugins/my-plugin/lib"
  echo "# plugin" > "$CT_HOME/plugins/my-plugin/plugins/my-plugin/plugin.md"
  echo "lib"      > "$CT_HOME/plugins/my-plugin/plugins/my-plugin/lib/util.sh"
  echo "readme"   > "$CT_HOME/plugins/my-plugin/README.md"

  run bash "$CT" add plugin my-plugin --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/plugins/my-plugin/plugin.md" ]
  [ -f "$PROJECT_DIR/.claude/plugins/my-plugin/lib/util.sh" ]
  [ ! -f "$PROJECT_DIR/.claude/plugins/my-plugin/README.md" ]
}

# ---------- 空 .ct-include の落とし穴 ----------

@test "空の .ct-include は無視され、自動検出が走る" {
  # 空の .ct-include（フィルタ無効化のつもりで作る人がいる想定）
  : > "$CT_HOME/skills/my-skill/.ct-include"
  mkdir -p "$CT_HOME/skills/my-skill/skills/my-skill"
  echo "# skill" > "$CT_HOME/skills/my-skill/skills/my-skill/SKILL.md"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
}

@test "コメント・空行のみの .ct-include は無視される" {
  printf '# only comment\n\n   \n' > "$CT_HOME/skills/my-skill/.ct-include"

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  # フィルタ無効扱い → ルートの全ファイルがコピーされる
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/README.md" ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/tests/test.sh" ]
}

@test ".ct-include なしで全コピー時、.ct-include 自体はコピー先に含まれない" {
  # ルート直下に .ct-include がある（パターンあり）と通常のフィルタが走るので、
  # サブディレクトリ自動検出のケースで .ct-include が無いことを確認
  : > "$CT_HOME/skills/my-skill/.ct-include"  # 空 → 自動検出走る

  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/.claude/skills/my-skill/.ct-include" ]
}
