#!/usr/bin/env bash
set -euo pipefail

source_root="${1:-}"
target_root="${2:-$PWD}"

if [ -z "$source_root" ]; then
  echo "usage: copy_project_local_config.sh <local-source-root> [target-workspace]" >&2
  exit 2
fi

if [ ! -d "$source_root" ]; then
  echo "warning: local config source not found: $source_root" >&2
  exit 0
fi

if [ ! -d "$target_root" ]; then
  echo "error: target workspace not found: $target_root" >&2
  exit 1
fi

source_root="$(cd "$source_root" && pwd)"
target_root="$(cd "$target_root" && pwd)"

copied_count=0
exclude_file="$target_root/.git/info/exclude"

add_git_exclude() {
  local rel="$1"

  if [ -f "$exclude_file" ] && ! grep -qxF "$rel" "$exclude_file"; then
    printf '%s\n' "$rel" >> "$exclude_file"
  fi
}

copy_one() {
  local source_path="$1"
  local rel="${source_path#$source_root/}"
  local target_path="$target_root/$rel"

  case "$rel" in
    .git/*|node_modules/*|.pnpm-store/*|.worktree/*|.artifacts/*|.codepilot-uploads/*)
      return
      ;;
    */node_modules/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*)
      return
      ;;
    *.example|*.example.*|*.prod.example)
      return
      ;;
  esac

  mkdir -p "$(dirname "$target_path")"
  rsync -aL "$source_path" "$target_path"
  add_git_exclude "$rel"

  case "$rel" in
    .mcp.json|*.pem|*.key|*.secret|*/.env|*/.env.*|.env|.env.*|*.local.json)
      chmod 600 "$target_path" 2>/dev/null || true
      ;;
  esac

  copied_count=$((copied_count + 1))
  echo "copied local config: $rel"
}

while IFS= read -r source_path; do
  copy_one "$source_path"
done < <(
  find "$source_root" \
    \( -path "$source_root/.git" \
    -o -path "$source_root/node_modules" \
    -o -path "$source_root/.pnpm-store" \
    -o -path "$source_root/.worktree" \
    -o -path "$source_root/.artifacts" \
    -o -path "$source_root/.codepilot-uploads" \
    -o -path "$source_root/**/node_modules" \
    -o -path "$source_root/**/dist" \
    -o -path "$source_root/**/build" \
    -o -path "$source_root/**/.next" \
    -o -path "$source_root/**/coverage" \) -prune \
    -o \( -type f -o -type l \) \( \
      -name '.env' \
      -o -name '.env.*' \
      -o -name '*.env' \
      -o -name '*.local' \
      -o -name '*.local.*' \
      -o -name '.mcp.json' \
      -o -name '*.pem' \
      -o -name '*.key' \
      -o -name '*.cert' \
      -o -name '*.p12' \
      -o -name '*.mobileprovision' \
    \) -print | sort
)

echo "local config copy complete: $copied_count file(s)"
