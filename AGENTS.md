# AGENTS.md

## 概要

`ct` は Bash 製の Claude / Codex tools マネージャーです。`src/ct` が本体で、スキル・プラグインを集約元からプロジェクトまたはグローバル配置先へコピー管理します。

## 作業ルール

- 日本語で簡潔に報告する。
- 既存の Bash スタイルに合わせ、外部入力は `validate_name` などで検証する。
- `.env`、秘密鍵、token、credential などの内容は出力しない。
- 動作コードを削除する場合は理由を説明する。
- 依頼範囲外のリファクタリングはしない。
- 未追跡ファイルや他者の変更を勝手に削除・上書きしない。

## テスト

変更後は可能な範囲で以下を実行する。

```bash
bash -n src/ct
bats tests/security.bats
bats tests/ct-include.bats
bats tests/codex-target.bats
```

`bats` がない環境では、実行できなかったことを報告する。
