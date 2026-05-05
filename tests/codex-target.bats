#!/usr/bin/env bats
# Codex target support tests

CT="$BATS_TEST_DIRNAME/../src/ct"

setup() {
  TEST_DIR="$(mktemp -d)"
  CT_HOME="$TEST_DIR/ct-home"
  PROJECT_DIR="$TEST_DIR/project"
  GLOBAL_AGENTS_DIR="$TEST_DIR/home/.agents"
  CODEX_HOME="$TEST_DIR/home/.codex"
  mkdir -p "$CT_HOME/skills" "$CT_HOME/plugins" "$PROJECT_DIR"

  mkdir -p "$CT_HOME/skills/my-skill"
  echo "# skill" > "$CT_HOME/skills/my-skill/SKILL.md"

  mkdir -p "$CT_HOME/plugins/my-plugin/.codex-plugin"
  cat > "$CT_HOME/plugins/my-plugin/.codex-plugin/plugin.json" <<'JSON'
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "Test plugin"
}
JSON
  mkdir -p "$CT_HOME/plugins/my-plugin/skills/hello"
  echo "# hello" > "$CT_HOME/plugins/my-plugin/skills/hello/SKILL.md"

  export CT_HOME PROJECT_DIR GLOBAL_AGENTS_DIR CODEX_HOME
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "codex skill: project は .agents/skills にコピーされる" {
  run bash "$CT" add skill my-skill --target codex --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.agents/skills/my-skill/SKILL.md" ]
  [ -f "$PROJECT_DIR/.agents/skills/.ct-manifest.json" ]
}

@test "既定 target は claude のまま維持される" {
  run bash "$CT" add skill my-skill --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/skills/my-skill/SKILL.md" ]
  [ ! -e "$PROJECT_DIR/.agents/skills/my-skill/SKILL.md" ]
}

@test "不正な target はエラーになる" {
  run bash "$CT" add skill my-skill --target unknown --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid target: unknown"* ]]
}

@test "codex skill: global は GLOBAL_AGENTS_DIR/skills にコピーされる" {
  run bash "$CT" add skill my-skill --target codex --global
  [ "$status" -eq 0 ]
  [ -f "$GLOBAL_AGENTS_DIR/skills/my-skill/SKILL.md" ]
  [ -f "$GLOBAL_AGENTS_DIR/skills/.ct-manifest.json" ]
}

@test "codex plugin: manifest がない場合はエラー" {
  mkdir -p "$CT_HOME/plugins/no-manifest"
  echo "x" > "$CT_HOME/plugins/no-manifest/file.txt"

  run bash "$CT" add plugin no-manifest --target codex --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"codex plugin manifest not found"* ]]
  [ ! -d "$PROJECT_DIR/plugins/no-manifest" ]
}

@test "codex plugin: project は plugins と marketplace に追加される" {
  run bash "$CT" add plugin my-plugin --target codex --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/plugins/my-plugin/.codex-plugin/plugin.json" ]
  [ -f "$PROJECT_DIR/plugins/.ct-manifest.json" ]
  [ -f "$PROJECT_DIR/.agents/plugins/marketplace.json" ]
  grep -q '"name": "ct-local"' "$PROJECT_DIR/.agents/plugins/marketplace.json"
  grep -q '"path": "./plugins/my-plugin"' "$PROJECT_DIR/.agents/plugins/marketplace.json"
}

@test "codex list --installed は codex 側の manifest を読む" {
  run bash "$CT" add skill my-skill --target codex --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  run bash "$CT" add plugin my-plugin --target codex --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]

  run bash "$CT" list --installed --target codex --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *".agents/skills"* ]]
  [[ "$output" == *"plugins"* ]]
  [[ "$output" == *"my-skill"* ]]
  [[ "$output" == *"my-plugin"* ]]
}

@test "codex plugin: global は CODEX_HOME/plugins と GLOBAL_AGENTS_DIR marketplace に追加される" {
  run bash "$CT" add plugin my-plugin --target codex --global
  [ "$status" -eq 0 ]
  [ -f "$CODEX_HOME/plugins/my-plugin/.codex-plugin/plugin.json" ]
  [ -f "$GLOBAL_AGENTS_DIR/plugins/marketplace.json" ]
  grep -q '"path": "./.codex/plugins/my-plugin"' "$GLOBAL_AGENTS_DIR/plugins/marketplace.json"
}

@test "codex plugin: sync はコピー内容と marketplace を維持する" {
  run bash "$CT" add plugin my-plugin --target codex --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]

  echo "# updated" > "$CT_HOME/plugins/my-plugin/skills/hello/SKILL.md"
  run bash "$CT" sync plugin my-plugin --target codex --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
  grep -q "updated" "$PROJECT_DIR/plugins/my-plugin/skills/hello/SKILL.md"
  grep -q '"path": "./plugins/my-plugin"' "$PROJECT_DIR/.agents/plugins/marketplace.json"
}

@test "codex plugin: remove はコピー先と marketplace entry を削除する" {
  run bash "$CT" add plugin my-plugin --target codex --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]

  run bash "$CT" remove plugin my-plugin --target codex --project "$PROJECT_DIR" -y
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/plugins/my-plugin" ]
  ! grep -q '"name": "my-plugin"' "$PROJECT_DIR/.agents/plugins/marketplace.json"
}

@test "codex plugin: 非 ct-local marketplace は上書きしない" {
  mkdir -p "$PROJECT_DIR/.agents/plugins"
  cat > "$PROJECT_DIR/.agents/plugins/marketplace.json" <<'JSON'
{
  "name": "team-marketplace",
  "plugins": []
}
JSON

  run bash "$CT" add plugin my-plugin --target codex --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not managed by ct"* ]]
  grep -q '"name": "team-marketplace"' "$PROJECT_DIR/.agents/plugins/marketplace.json"
  [ ! -d "$PROJECT_DIR/plugins/my-plugin" ]
}
