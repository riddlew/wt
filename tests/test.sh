#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
export GIT_CONFIG_GLOBAL="$TEMP/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
export HOME="$TEMP/home"
mkdir -p "$HOME"
mkdir -p "$TEMP/repo"
cd "$TEMP/repo"
git init -q -b main
git config user.email tests@example.com
git config user.name Tests
printf 'hello\n' > tracked.txt
git add .; git commit -qm initial
# Git config wizard: whitespace-only input selects built-ins.
printf '  \n\t\n\n\n\n\n\n\n\n\n' | "$ROOT/wt" config > "$TEMP/wizard.txt"
[[ "$(git config --global wt.root)" == '~/.worktrees' ]]
[[ "$(git config --global wt.strategy)" == global ]]
[[ "$(git config --global wt.separator)" == / ]]
"$ROOT/wt" create feature-one > "$TEMP/path"
path=$(cat "$TEMP/path")
[[ -d "$path" && "$path" == "$HOME/.worktrees/repo/feature-one" ]]
[[ "$(git -C "$path" branch --show-current)" == feature-one ]]
[[ "$("$ROOT/wt" cd feature-one)" == "$path" ]]
[[ "$("$ROOT/wt" co feature-one)" == "$path" ]]
"$ROOT/wt" status | grep -q feature-one
"$ROOT/wt" ls | grep -q feature-one
"$ROOT/wt" rm feature-one
[[ ! -e "$path" ]]
# User-configured strategies, branch separators, and paths with spaces.
git config --global wt.strategy sibling-repo
git config --global wt.separator -
"$ROOT/wt" create feat/with-slash > "$TEMP/path"
path=$(cat "$TEMP/path")
[[ -d "$path" && "$path" == "$TEMP/repo-feat-with-slash" ]]
# Existing branch is checked out into a new worktree.
"$ROOT/wt" rm feat/with-slash
[[ -z "$(git worktree list --porcelain | grep feat-with-slash || :)" ]]
"$ROOT/wt" co feat/with-slash >/dev/null
# Dirty worktrees cannot be deleted without explicit cleanup.
printf 'dirty\n' > "$path/untracked.txt"
if "$ROOT/wt" rm feat/with-slash >/dev/null 2>&1; then echo 'ERROR: removed dirty worktree' >&2; exit 1; fi
rm "$path/untracked.txt"
"$ROOT/wt" rm feat/with-slash
# Remove by actual worktree directory name, not only the branch name.
git config --global wt.strategy global
git config --global wt.root "$TEMP/named-worktrees"
"$ROOT/wt" create fix/do-thing > "$TEMP/path"
path=$(cat "$TEMP/path")
[[ "${path##*/}" == fix-do-thing ]]
"$ROOT/wt" rm fix-do-thing
[[ ! -e "$path" ]]
"$ROOT/wt" co fix/do-thing > "$TEMP/path"
path=$(cat "$TEMP/path")
"$ROOT/wt" rm fix/do-thing
[[ ! -e "$path" ]]
# If a branch name is also another worktree's directory name,
# refuse to guess which worktree the user intended to remove.
"$ROOT/wt" co fix/do-thing > "$TEMP/path"
path=$(cat "$TEMP/path")
# Navigation accepts branch names, folder names, and full paths.
[[ "$("$ROOT/wt" cd fix/do-thing)" == "$path" ]]
[[ "$("$ROOT/wt" cd fix-do-thing)" == "$path" ]]
[[ "$("$ROOT/wt" sw fix-do-thing)" == "$path" ]]
[[ "$("$ROOT/wt" switch fix-do-thing)" == "$path" ]]
[[ "$("$ROOT/wt" cd "$path")" == "$path" ]]
# Unknown copy target must not silently fall back to the current checkout.
if "$ROOT/wt" copy not-an-existing-worktree > /dev/null 2>&1; then
  echo 'ERROR: wt copy accepted a missing target' >&2; exit 1
fi
git worktree add -q -b fix-do-thing "$TEMP/other-branch" main
if "$ROOT/wt" rm fix-do-thing > "$TEMP/ambiguous.stdout" 2> "$TEMP/ambiguous.stderr"; then
  echo 'ERROR: ambiguous worktree name was accepted' >&2; exit 1
fi
grep -q 'ambiguous worktree' "$TEMP/ambiguous.stderr"
if "$ROOT/wt" cd fix-do-thing > /dev/null 2>&1; then
  echo 'ERROR: ambiguous cd target selected' >&2; exit 1
fi
if "$ROOT/wt" copy fix-do-thing > /dev/null 2>&1; then
  echo 'ERROR: ambiguous copy target selected' >&2; exit 1
fi
[[ -d "$path" && -d "$TEMP/other-branch" ]]
"$ROOT/wt" rm "$path"
"$ROOT/wt" rm fix-do-thing
[[ ! -e "$path" && ! -e "$TEMP/other-branch" ]]
# Preserve spaces in worktree root.
git config --global wt.strategy global
git config --global wt.root "$TEMP/root with spaces"
"$ROOT/wt" create with-spaces > "$TEMP/path"
[[ -d "$(cat "$TEMP/path")" ]]
# Config scope override.
"$ROOT/wt" config set strategy parent-dotdir --global
[[ "$(git config --global wt.strategy)" == parent-dotdir ]]
"$ROOT/wt" config --local set strategy parent-branches
[[ "$(git config --local wt.strategy)" == parent-branches ]]
# File copying from main checkout.
printf '.env\n' >> .gitignore
git add .gitignore; git commit -qm ignore-env
printf 'TOKEN=x\n' > .env
git config --local --add wt.copy .env
"$ROOT/wt" create copy-env > "$TEMP/path"
[[ "$(cat "$(cat "$TEMP/path")/.env")" == 'TOKEN=x' ]]
copy_path=$(cat "$TEMP/path")
rm "$copy_path/.env"
"$ROOT/wt" copy copy-env
[[ "$(cat "$copy_path/.env")" == 'TOKEN=x' ]]
rm "$copy_path/.env"
"$ROOT/wt" copy "$copy_path"
[[ "$(cat "$copy_path/.env")" == 'TOKEN=x' ]]
echo 'tests passed'
