# Codex 向けガイド

このドキュメントは Codex、および Codex と同様に `AGENTS.md` を入口にする AI エージェント向けの固有ルールです。共通ルールは `docs/ai/shared.md` を参照してください。

## 入口

- Codex / 汎用 AI エージェントの入口は `AGENTS.md` とする。
- 作業開始時は `AGENTS.md` と `docs/ai/shared.md` を優先して確認する。
- Claude Code 固有の入口である `CLAUDE.md` は維持し、Codex 向けに置き換えない。

## 作業ルール

- 日本語で簡潔に報告する。
- 実装前に計画を提示し、明示的な承認を得てから変更する。
- ファイル変更前に、変更対象と変更内容の概要を提示する。
- 一度に大量のファイルを変更せず、段階的に進める。
- 読み取り系の `git status`、`git diff`、`git log`、`git show`、`ls`、`rg`、`grep`、`find` では、正確な生出力が不要なら `rtk` 経由を優先する。
- `.claude` 配下は Claude Code の既存運用に関わるため、明示的な依頼なしに変更しない。
- `.codex` 配下を使う場合も、Claude Code の設定や運用を壊さないよう分離する。

## セキュリティ

- `.env`、秘密鍵、認証情報、token、credential などの内容は出力しない。
- 外部入力を扱う変更では、`validate_name` などの既存検証ルールを確認する。
- 依存パッケージを追加する場合は、必要性を説明してから追加する。

## テスト

変更後は可能な範囲で以下を実行する。

```bash
bash -n src/ct
bats tests/security.bats
bats tests/ct-include.bats
bats tests/codex-target.bats
```

`bats` コマンドがない場合は、プロジェクト内の `tests/bats` を確認する。実行できなかった場合は、理由を簡潔に報告する。
