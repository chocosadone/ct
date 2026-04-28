#!/usr/bin/env bats
# セキュリティ強化タスク (T1〜T5) の受け入れテスト

CT="$BATS_TEST_DIRNAME/../src/ct"

# ---------- セットアップ ----------

setup() {
  # テストごとに独立した一時ディレクトリを用意する
  TEST_DIR="$(mktemp -d)"
  CT_HOME="$TEST_DIR/ct-home"
  DEST_DIR="$TEST_DIR/dest"
  mkdir -p "$CT_HOME/skills" "$CT_HOME/plugins" "$DEST_DIR"

  # ct add/sync/remove が参照するプロジェクトディレクトリ
  PROJECT_DIR="$TEST_DIR/project"
  mkdir -p "$PROJECT_DIR"

  # テスト用のダミースキルソースを作成しておく
  mkdir -p "$CT_HOME/skills/my-skill"
  echo "dummy" > "$CT_HOME/skills/my-skill/file.txt"

  export CT_HOME PROJECT_DIR
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ---------- T2: name バリデーション（不正な入力を弾く） ----------

@test "T2: add - ../foo はエラーになる" {
  run bash "$CT" add skill '../foo' --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid name"* ]]
}

@test "T2: add - スラッシュ含む名前はエラー" {
  run bash "$CT" add skill 'foo/bar' --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid name"* ]]
}

@test "T2: add - スペース含む名前はエラー" {
  run bash "$CT" add skill 'foo bar' --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid name"* ]]
}

@test "T2: add - セミコロン含む名前はエラー" {
  run bash "$CT" add skill 'foo;bar' --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid name"* ]]
}

@test "T2: add - 空文字名はエラー" {
  run bash "$CT" add skill '' --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  # invalid name または usage エラーのいずれかで終了すること
  [ -n "$output" ]
}

@test "T2: remove - ../foo はエラーになる" {
  run bash "$CT" remove skill '../foo' --project "$PROJECT_DIR" -y
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid name"* ]]
}

@test "T2: sync - ../foo はエラーになる" {
  run bash "$CT" sync skill '../foo' --project "$PROJECT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid name"* ]]
}

@test "T2: register - --name に ../foo を渡すとエラー" {
  run bash "$CT" register skill 'https://example.com/foo.git' --name '../foo'
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid name"* ]]
}

# ---------- T2: 正常な名前は通過する ----------

@test "T2: 英数字のみの名前は add で受け付けられる" {
  run bash "$CT" add skill 'my-skill' --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
}

@test "T2: ドット・ハイフン・アンダースコアを含む名前は有効" {
  # ソースを用意
  mkdir -p "$CT_HOME/skills/my.skill_v1-2"
  echo "x" > "$CT_HOME/skills/my.skill_v1-2/f"
  run bash "$CT" add skill 'my.skill_v1-2' --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]
}

@test "T2: register - URL の basename が有効な名前なら通過する" {
  # git clone をスタブして実際のネットワークアクセスを回避
  stub_git_clone() {
    mkdir -p "$2"
  }
  # PATH の先頭にスタブディレクトリを置いて git を差し替える
  local stub_dir="$TEST_DIR/stub"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/git" <<'STUB'
#!/usr/bin/env bash
# clone のみをスタブ、それ以外はシステム git に委譲
if [[ "$1" == "clone" ]]; then
  # 最後の引数がターゲットパス
  target="${@: -1}"
  mkdir -p "$target"
  exit 0
fi
exec /usr/bin/git "$@"
STUB
  chmod +x "$stub_dir/git"

  run env PATH="$stub_dir:$PATH" bash "$CT" register skill 'https://example.com/valid-name.git'
  [ "$status" -eq 0 ]
  [[ "$output" == *"registered"* ]]
}

# ---------- T1: git clone の -- セパレータ（オプション注入対策） ----------

@test "T1: register に --upload-pack=evil を URL として渡しても git オプション扱いにならない" {
  local stub_dir="$TEST_DIR/stub"
  mkdir -p "$stub_dir"

  # git clone の引数を記録するスタブ
  cat > "$stub_dir/git" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "clone" ]]; then
  # 引数を全てファイルに記録
  printf '%s\n' "$@" > "${BATS_TEST_TMPDIR}/git_args"
  # -- の次の引数（URL）を取り出して確認のため終了コードで返す
  # --upload-pack=evil がオプションとして渡っていたらスタブ的に検出できるよう
  # ここでは引数ログだけ残して失敗させる（clone が成功しなくていい）
  exit 128
fi
exec /usr/bin/git "$@"
STUB
  chmod +x "$stub_dir/git"

  run env PATH="$stub_dir:$PATH" bash "$CT" register skill '--upload-pack=evil'
  # -- セパレータがあれば git は URL として処理しようとして失敗する（128 等）
  # オプションとして解釈されていないことを引数ログで確認
  if [[ -f "$BATS_TEST_TMPDIR/git_args" ]]; then
    # 引数リストに -- が含まれていること
    grep -Fxq -- '--' "$BATS_TEST_TMPDIR/git_args"
  fi
  # invalid name または git エラーで終了していること（正常終了 0 ではない）
  [ "$status" -ne 0 ]
}

# ---------- T3: json_escape - マニフェスト書き込みエスケープ ----------

@test "T3: CT_HOME にスペースを含むパスでも add 後のマニフェストが壊れない" {
  local spaced_home="$TEST_DIR/ct home with spaces"
  mkdir -p "$spaced_home/skills/my-skill"
  echo "x" > "$spaced_home/skills/my-skill/f"

  run env CT_HOME="$spaced_home" bash "$CT" add skill 'my-skill' --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]

  # マニフェストが有効な JSON として読めること（source フィールドが存在する）
  local mf="$PROJECT_DIR/.claude/skills/.ct-manifest.json"
  [ -f "$mf" ]
  # source フィールドに "my-skill" への参照が含まれること
  grep -q '"source"' "$mf"
  # 二重引用符が対応していること（簡易チェック: " の個数が偶数）
  local q_count
  q_count=$(grep -o '"' "$mf" | wc -l)
  [ $(( q_count % 2 )) -eq 0 ]
}

@test "T3: CT_HOME にダブルクォートを含むパスでも add 後のマニフェストが壊れない" {
  # ディレクトリ名にダブルクォートを使う
  local quoted_home="$TEST_DIR/ct-home-with-\"quote\""
  mkdir -p "$quoted_home/skills/my-skill"
  echo "x" > "$quoted_home/skills/my-skill/f"

  run env CT_HOME="$quoted_home" bash "$CT" add skill 'my-skill' --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]

  local mf="$PROJECT_DIR/.claude/skills/.ct-manifest.json"
  [ -f "$mf" ]
  # エスケープされた \" が含まれていること
  grep -q '\\"' "$mf"
  # ファイル内の " の個数が偶数（JSON として対応している）
  local q_count
  q_count=$(grep -o '"' "$mf" | wc -l)
  [ $(( q_count % 2 )) -eq 0 ]
}

@test "T3: CT_HOME にバックスラッシュを含むパスでも add 後のマニフェストが壊れない" {
  local bs_home="$TEST_DIR/ct-home-with-\\backslash"
  mkdir -p "$bs_home/skills/my-skill"
  echo "x" > "$bs_home/skills/my-skill/f"

  run env CT_HOME="$bs_home" bash "$CT" add skill 'my-skill' --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]

  local mf="$PROJECT_DIR/.claude/skills/.ct-manifest.json"
  [ -f "$mf" ]
  # エスケープされた \\\\ が含まれていること
  grep -q '\\\\' "$mf"
}

# ---------- T5: mktemp が同一ディレクトリに作られる ----------

@test "T5: add 中に作られる一時ファイルはマニフェストと同じディレクトリにある" {
  # inotifywait が使えない環境のため、add 直後に残留しないことを確認する代替策として
  # マニフェストと同ディレクトリ以外に .XXXXXX パターンのファイルが残らないことを確認する
  run bash "$CT" add skill 'my-skill' --project "$PROJECT_DIR"
  [ "$status" -eq 0 ]

  local mf_dir="$PROJECT_DIR/.claude/skills"
  # /tmp 配下に ct が作った一時ファイルが残っていないこと
  # (mktemp "$mf.XXXXXX" なら同ディレクトリに作られ、mv 後に自動削除される)
  local leftover
  leftover=$(find /tmp -maxdepth 1 -name ".ct-manifest.json.*" 2>/dev/null | wc -l)
  [ "$leftover" -eq 0 ]

  # マニフェストが正常に存在すること
  [ -f "$mf_dir/.ct-manifest.json" ]
}

# ---------- T4: 並行書き込みでマニフェストが壊れない ----------

@test "T4: 2 プロセス同時 add でもマニフェストが破損しない" {
  # 2 つ目のスキルソースを用意
  mkdir -p "$CT_HOME/skills/skill-a" "$CT_HOME/skills/skill-b"
  echo "a" > "$CT_HOME/skills/skill-a/f"
  echo "b" > "$CT_HOME/skills/skill-b/f"

  # 並行実行
  bash "$CT" add skill 'skill-a' --project "$PROJECT_DIR" &
  bash "$CT" add skill 'skill-b' --project "$PROJECT_DIR" &
  wait

  local mf="$PROJECT_DIR/.claude/skills/.ct-manifest.json"
  [ -f "$mf" ]

  # 両エントリがマニフェストに存在すること
  grep -q '"skill-a"' "$mf"
  grep -q '"skill-b"' "$mf"

  # JSON として最低限の構造が維持されていること
  # （{ と } の個数が一致する）
  local open close
  open=$(grep -o '{' "$mf" | wc -l)
  close=$(grep -o '}' "$mf" | wc -l)
  [ "$open" -eq "$close" ]
}
