# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 入口

Claude Code はこのファイルを入口として扱ってください。共通ルールとプロジェクト仕様は `docs/ai/shared.md`、Claude Code 固有ルールは `docs/ai/claude.md` に分離しています。

作業時は以下を確認してください。

1. `docs/ai/shared.md`
2. `docs/ai/claude.md`

Codex / 汎用 AI エージェント向けの入口は `AGENTS.md` です。Claude Code の既存運用を壊さないため、`CLAUDE.md` は Claude Code 用入口として維持します。

## 概要

`ct` は Bash 製の Claude / Codex tools マネージャーです。`src/ct` が本体で、スキル・プラグインを集約元からプロジェクトまたはグローバル配置先へコピー管理します。

詳細な仕様、アーキテクチャ、コマンドフロー、テスト手順は `docs/ai/shared.md` を参照してください。

## Claude Code 固有の注意

- `.claude/settings.local.json` は Claude Code のローカル設定として尊重する。
- `.claude` 配下の設定・hook・権限設定は、明示的な依頼がない限り変更しない。
- 未指定時は `--target claude` と同じ既存挙動を維持する。
- Codex 対応を追加・変更する場合でも、Claude Code の既存運用を壊さない。

## 変更後の確認

変更後は可能な範囲で以下を実行してください。

```bash
bash -n src/ct
bats tests/security.bats
bats tests/ct-include.bats
bats tests/codex-target.bats
```

`bats` コマンドがない場合は、プロジェクト内の `tests/bats` を確認してください。実行できなかった場合は、その旨を報告してください。
