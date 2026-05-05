# Claude Code 向けガイド

このドキュメントは Claude Code 向けの固有ルールです。共通ルールは `docs/ai/shared.md` を参照してください。

## 入口

- Claude Code の入口は `CLAUDE.md` とする。
- `CLAUDE.md` は削除せず、Claude Code が最初に読むファイルとして維持する。
- Codex / 汎用 AI エージェント向けの入口は `AGENTS.md` とし、Claude Code 用の入口とは分離する。

## 既存運用の尊重

- `.claude/settings.local.json` は Claude Code のローカル設定として扱う。
- `.claude` 配下の設定・hook・権限設定は、明示的な依頼がない限り変更しない。
- `--target claude` および未指定時の既存挙動を壊さない。
- Claude 用の `.claude/skills`、`.claude/plugins`、`.ct-manifest.json` の仕様は `docs/ai/shared.md` のアーキテクチャとマニフェスト仕様に従う。

## 作業ルール

- 日本語で簡潔に報告する。
- 変更前に対象ファイルと変更内容を説明する。
- 既存の Bash スタイル、命名規則、検証方針を維持する。
- Codex 対応を追加・変更する場合でも、Claude Code の既存運用を壊さないことを優先する。

## テスト

変更後は可能な範囲で以下を実行する。

```bash
bash -n src/ct
bats tests/security.bats
bats tests/ct-include.bats
bats tests/codex-target.bats
```

`bats` コマンドがない場合は、プロジェクト内の `tests/bats` を確認する。実行できなかった場合は、理由を簡潔に報告する。
