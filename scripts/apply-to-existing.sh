#!/usr/bin/env bash
# テンプレートの Claude Code 設定を既存の git リポジトリに導入、更新する。
set -euo pipefail

usage() {
  cat <<'EOF'
使い方: apply-to-existing.sh [オプション] <対象リポジトリ>

オプション:
  --local    変更を git に載せない（.git/info/exclude に追加する）
  --update   内容が異なるスキルとエージェントをテンプレートの内容で上書きする
  --dry-run  実行内容だけを表示し、何も変更しない
  -h, --help このヘルプを表示する

CLAUDE.md と .claude/settings.json は、既にあれば変更しません。
EOF
}

local_mode=false
update=false
dry_run=false
target=""

while [ $# -gt 0 ]; do
  case "$1" in
    --local) local_mode=true ;;
    --update) update=true ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "不明なオプション: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [ -n "$target" ]; then
        echo "対象リポジトリは1つだけ指定してください" >&2
        exit 2
      fi
      target="$1"
      ;;
  esac
  shift
done

if [ -z "$target" ]; then
  usage >&2
  exit 2
fi

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git リポジトリではありません: $target" >&2
  exit 1
fi
target_root="$(git -C "$target" rev-parse --show-toplevel)"

if [ "$source_dir" = "$target_root" ]; then
  echo "テンプレート自身には導入できません" >&2
  exit 1
fi

say() { printf '%-8s %s\n' "$1" "$2"; }

# 親ディレクトリを作ってファイルをコピーする
copy_file() {
  if ! "$dry_run"; then
    mkdir -p "$(dirname "$target_root/$1")"
    cp "$source_dir/$1" "$target_root/$1"
  fi
}

# git で追跡中のパスは exclude の対象にならない
is_tracked() {
  git -C "$target_root" ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

managed_paths=()
while IFS= read -r path; do
  managed_paths+=("$path")
done < <(cd "$source_dir" && find .claude/skills .claude/agents -type f | sed 's|^\./||' | sort)

created_paths=()

for path in "${managed_paths[@]}"; do
  if [ ! -e "$target_root/$path" ]; then
    copy_file "$path"
    created_paths+=("$path")
    say "追加" "$path"
  elif cmp -s "$source_dir/$path" "$target_root/$path"; then
    say "同一" "$path"
  elif "$update"; then
    copy_file "$path"
    say "更新" "$path"
  else
    say "スキップ" "$path（内容が異なります。上書きは --update）"
  fi
done

for path in CLAUDE.md .claude/settings.json; do
  if [ -e "$target_root/$path" ]; then
    say "保持" "$path"
  else
    copy_file "$path"
    created_paths+=("$path")
    say "追加" "$path"
  fi
done

# 既にあれば追記しない
add_line() {
  local file="$1" line="$2"
  if [ -f "$file" ] && grep -qxF -- "$line" "$file"; then
    return 0
  fi
  say "追記" "${file#"$target_root"/}: $line"
  if "$dry_run"; then
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
    printf '\n' >>"$file"
  fi
  printf '%s\n' "$line" >>"$file"
}

ignored_lines=(".claude/settings.local.json" ".claude/worktrees/" "CLAUDE.local.md")

if "$local_mode"; then
  exclude_file="$(git -C "$target_root" rev-parse --path-format=absolute --git-path info/exclude)"
  for line in "${ignored_lines[@]}"; do
    add_line "$exclude_file" "$line"
  done
  for path in "${managed_paths[@]}" CLAUDE.md .claude/settings.json; do
    if ! is_tracked "$path"; then
      add_line "$exclude_file" "$path"
    fi
  done
else
  for line in "${ignored_lines[@]}"; do
    add_line "$target_root/.gitignore" "$line"
  done
fi

if [ -e "$target_root/.claude/settings.json" ] && ! printf '%s\n' "${created_paths[@]:-}" | grep -qxF ".claude/settings.json"; then
  cat <<'EOF'

既存の .claude/settings.json は変更していません。必要なら次の項目を追加してください:
  "model": "sonnet",
  "advisorModel": "opus",
  "worktree": { "baseRef": "head" }
EOF
fi

if "$dry_run"; then
  printf '\nドライランのため、何も変更していません。\n'
else
  printf '\n完了しました。対象リポジトリで claude を起動し、/setup を実行してください。\n'
fi
