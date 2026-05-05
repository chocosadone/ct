# AGENTS.md

Codex / 汎用 AI エージェントはこのファイルを入口として扱ってください。共通ルールとプロジェクト仕様は `docs/ai/shared.md`、Codex 固有ルールは `docs/ai/codex.md` に分離しています。

## 参照順

1. `docs/ai/shared.md`
2. `docs/ai/codex.md`

Claude Code 向けの入口は `CLAUDE.md` です。Claude Code の既存運用を壊さないため、`CLAUDE.md` は Claude Code 用入口として維持します。

## 概要

`ct` は Bash 製の Claude / Codex tools マネージャーです。`src/ct` が本体で、スキル・プラグインを集約元からプロジェクトまたはグローバル配置先へコピー管理します。

## 作業ルール

- 日本語で簡潔に報告する。
- 既存の Bash スタイルに合わせ、外部入力は `validate_name` などで検証する。
- `.env`、秘密鍵、認証情報、token、credential などの内容は出力しない。
- 動作コードを削除する場合は理由を説明する。
- 依頼範囲外のリファクタリングはしない。
- 未追跡ファイルや他者の変更を勝手に削除・上書きしない。
- 実装前に計画を提示し、承認を得てから変更する。
- `.claude` 配下は、明示的な依頼なしに変更しない。

## テスト

変更後は可能な範囲で以下を実行する。

```bash
bash -n src/ct
bats tests/security.bats
bats tests/ct-include.bats
bats tests/codex-target.bats
```

`bats` コマンドがない場合は、プロジェクト内の `tests/bats` を確認する。実行できなかった場合は、理由を報告する。
