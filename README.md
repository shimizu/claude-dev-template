# claude-dev-template

Claude Code で開発を進めるための、技術スタックに依存しないテンプレートです。Sonnet が実装し、難しい局面で Opus の advisor に相談し、広い調査と機械的な検査を Haiku に任せます。

## 使い方

### 新規プロジェクト

```bash
gh repo create my-app --template <GitHubユーザー名>/claude-dev-template --private --clone
cd my-app
claude
```

起動したら `/setup` を実行します。リポジトリを調べて `CLAUDE.md` の未設定の項目を埋めます。

### 既存のリポジトリ

```bash
# このテンプレートを手元にクローンしておき、対象リポジトリを指定して実行する
claude-dev-template/scripts/apply-to-existing.sh <対象リポジトリ>
```

| オプション | 用途 |
|---|---|
| `--local` | 他人のリポジトリなど、変更を git に載せたくないとき |
| `--update` | テンプレートを改善したあと、スキルとエージェントを更新するとき |
| `--dry-run` | 実行内容だけを確認するとき |

`CLAUDE.md` と `.claude/settings.json` は、既にあれば変更しません。

## コマンド

| コマンド | 内容 |
|---|---|
| `/setup` | `CLAUDE.md` を埋める |
| `/fix <不具合>` | 再現、失敗するテスト、原因の特定、最小限の修正 |
| `/feature <内容>` | 調査、計画、advisor への相談、合意、実装 |
| `/finish` | テスト、変更の検査、advisor のレビュー、コミットと PR の案 |

小さな修正なら、コマンドを使わず普通に頼めば十分です。コミットと push は、指示があるまで行いません。

## モデルの分担

| 役割 | モデル | 設定場所 |
|---|---|---|
| 実装 | Sonnet | `.claude/settings.json` の `model` |
| 方針の相談、レビュー | Opus | `.claude/settings.json` の `advisorModel` |
| 広い範囲の調査 | Haiku | `.claude/agents/Explore.md` |
| 変更の機械的な検査 | Haiku | `.claude/agents/audit.md` |

- advisor を呼ぶタイミングは Claude が判断します。スキルは相談するよう指示していますが、確実な呼び出しを保証するものではありません。
- advisor は実験的な機能で、サブスクリプションと API 課金のどちらでも使えます。Amazon Bedrock、Google Cloud、Microsoft Foundry 経由では使えません。呼び出すたびに Opus のトークンを消費します。短い作業では `/advisor off` で切れます。
- `Explore.md` は組み込みの Explore を置き換えて Haiku で動かします。元に戻すときは、このファイルを削除します。
- audit と Explore は書き込みツールを持ちませんが、Bash は使えるので、読み取り専用は指示に基づくものです。

## worktree について

`worktree.baseRef` を `head` にしているので、worktree は origin/main ではなく手元の HEAD から作られます。未コミットの変更は引き継がれないため、並行作業を頼む前にコミットしてください。`.env` などの除外ファイルが必要なら `.worktreeinclude` に書きます。

audit に `isolation: worktree` を付けないでください。検査すべき未コミットの変更が見えなくなります。

## カスタマイズ

- プロジェクト固有の情報は `CLAUDE.md` に、自分だけの設定は `CLAUDE.local.md` と `.claude/settings.local.json` に書きます。
- 手順を変えるときは `.claude/skills/*/SKILL.md` を編集します。スキルにはテストの具体的なコマンドを書かず、`CLAUDE.md` を参照させます。

## テンプレートの公開

```bash
git init -b main
git add .
git commit -m "Initial commit"
gh repo create claude-dev-template --private --source=. --push
gh repo edit --template
```
