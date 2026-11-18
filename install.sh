#!/usr/bin/env bash
# install.sh — make the jlu skills available to opencode, Claude Code and Codex.
#
# Default mode links (symlinks) each skill from THIS repo into each tool's
# global skills directory. Symlinks mean the repo stays the single source of
# truth: update once with `git pull`, and every tool picks up the change on
# its next session scan. No files are duplicated. Stale links to skills that
# were deleted from the repo are pruned automatically.
#
# Usage:
#   ./install.sh                 link your skills (opencode + claude + codex)
#   ./install.sh --tools=codex   only link for a specific tool (comma-separated)
#   ./install.sh --copy          copy files instead of symlinking (e.g. unusual filesystems)
#   ./install.sh --unlink        remove your skills from the tool directories
#   ./install.sh --force         replace an existing file/dir/symlink that is in the way
#
# Env overrides (defaults in parentheses):
#   OPENCODE_SKILLS_DIR  (~/.config/opencode/skills)
#   CLAUDE_SKILLS_DIR    (~/.claude/skills)
#   CODEX_HOME           (~/.codex)      -> skills go in $CODEX_HOME/skills
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Every directory in this repo that contains a SKILL.md is a skill.
SKILLS=()
for _d in "$REPO_DIR"/*/; do
  [ -f "$_d/SKILL.md" ] && SKILLS+=("$(basename "$_d")")
done
if [ "${#SKILLS[@]}" -eq 0 ]; then
  echo "error: no skills (SKILL.md) found in $REPO_DIR" >&2
  exit 1
fi

MODE=symlink
UNLINK=0
FORCE=0
TOOLS=(opencode claude codex)

target_dir() {
  case "$1" in
    opencode) printf '%s' "${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}" ;;
    claude)   printf '%s' "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}" ;;
    codex)    printf '%s' "${CODEX_HOME:-$HOME/.codex}/skills" ;;
    *) printf '' ;;
  esac
}

usage() {
  grep -E '^# ' "$0" | sed 's/^# \?//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --copy)    MODE=copy ;;
    --unlink)  UNLINK=1 ;;
    --force)   FORCE=1 ;;
    --tools=*) IFS=',' read -r -a TOOLS <<< "${1#--tools=}" ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
  shift
done

link_one() { # source_dir target_dir skill
  local src="$1" target_base="$2" name="$3"
  local target="$target_base/$name"
  mkdir -p "$target_base"
  if [ -L "$target" ]; then
    local cur; cur="$(readlink "$target")"
    if [ "$cur" = "$src" ]; then
      echo "  ok   $target -> $src"
      return 0
    fi
    echo "  rm   stale symlink $target (was -> $cur)"
    rm "$target"
  elif [ -e "$target" ]; then
    if [ "$FORCE" -eq 1 ]; then
      echo "  rm   conflicting entry $target (--force)"
      rm -rf "$target"
    else
      echo "  skip $target exists and is not a symlink (use --force to replace)" >&2
      return 1
    fi
  fi
  if [ "$MODE" = copy ]; then
    cp -r "$src" "$target"
    echo "  copy $src -> $target"
  else
    ln -s "$src" "$target"
    echo "  link $src -> $target"
  fi
}

unlink_one() {
  local target_base="$1" name="$2"
  local target="$target_base/$name"
  if [ -L "$target" ] || [ -e "$target" ]; then
    rm -rf "$target"
    echo "  rm   $target"
  else
    echo "  --   $target (absent)"
  fi
}

# Remove symlinks in a tool dir that point into this repo but whose skill is
# no longer present here (e.g. after a skill was deleted and `git pull` ran).
prune_stale() {
  local target_base="$1"
  [ -d "$target_base" ] || return 0
  local name cur
  for entry in "$target_base"/*; do
    [ -L "$entry" ] || continue
    name="$(basename "$entry")"
    cur="$(readlink "$entry")"
    case "$cur" in
      "$REPO_DIR"/*) ;;
      *) continue ;;
    esac
    for s in "${SKILLS[@]}"; do
      [ "$s" = "$name" ] && continue 2
    done
    echo "  rm   stale $entry (skill no longer in repo)"
    rm "$entry"
  done
}

rc=0
for tool in "${TOOLS[@]}"; do
  dir="$(target_dir "$tool")"
  if [ -z "$dir" ]; then echo "error: unknown tool '$tool' (opencode|claude|codex)" >&2; rc=1; continue; fi
  echo "[$tool] $dir"
  if [ "$UNLINK" -eq 1 ]; then
    for skill in "${SKILLS[@]}"; do
      unlink_one "$dir" "$skill"
    done
  else
    for skill in "${SKILLS[@]}"; do
      link_one "$REPO_DIR/$skill" "$dir" "$skill" || rc=1
    done
    prune_stale "$dir"
  fi
done

echo ""
if [ "$UNLINK" -eq 1 ]; then
  echo "Unlinked."; echo "Tip: your skills still live in $REPO_DIR; nothing was deleted."
else
  echo "Done. Skills now come from $REPO_DIR (symlink mode)."
  echo "To update on this device later: git -C \"$REPO_DIR\" pull"
fi
exit "$rc"