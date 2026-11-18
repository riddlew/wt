#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" GIT_CONFIG_GLOBAL="$TMP/global-config" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$TMP/repo" "$TMP/bin"
cd "$TMP/repo"
git init -qb main
git config user.email tests@example.com
git config user.name Tests
printf 'initial\n' > tracked
git add tracked
git commit -qm initial
export PATH="$ROOT:$PATH"
git config --global wt.root "$TMP/worktrees"
git config --global wt.strategy global
git config --global wt.separator -

# Both the branch and worktree path change, preserving uncommitted files.
wt create fix/do-thing > "$TMP/old-path"
old=$(cat "$TMP/old-path")
printf 'uncommitted\n' > "$old/local.txt"
new=$(wt rename fix/do-thing fix/new-thing)
[[ "$new" == "$TMP/worktrees/repo/fix-new-thing" && -d "$new" ]]
[[ ! -e "$old" && "$(cat "$new/local.txt")" == uncommitted ]]
[[ "$(git -C "$new" branch --show-current)" == fix/new-thing ]]
! git show-ref -q --verify refs/heads/fix/do-thing
[[ "$(wt cd fix-new-thing)" == "$new" ]]

# Existing worktree folder names work as OLD arguments.
third=$(wt rename fix-new-thing fix/third)
[[ "$(git -C "$third" branch --show-current)" == fix/third ]]
[[ "$third" == "$TMP/worktrees/repo/fix-third" ]]

# The one-argument form renames the branch checked out in the current worktree.
fourth=$(cd "$third" && wt rename fix/fourth)
[[ "$fourth" == "$TMP/worktrees/repo/fix-fourth" ]]
[[ ! -e "$third" && -d "$fourth" ]]

# The shell wrapper follows renamed current worktrees, even from a subdirectory.
mkdir -p "$fourth/subdir"
(
  source "$ROOT/shell/wt.bash"
  cd "$fourth/subdir"
  wt rename fix/fifth > "$TMP/shell-output"
  [[ "$PWD" == "$TMP/worktrees/repo/fix-fifth/subdir" ]]
  [[ -z "$(cat "$TMP/shell-output")" ]]
)
fifth="$TMP/worktrees/repo/fix-fifth"
[[ -d "$fifth" ]]

# Renames of the primary worktree are prohibited.
if wt rename main production > /dev/null 2> "$TMP/error"; then echo 'primary rename incorrectly succeeded' >&2; exit 1; fi
grep -q 'primary worktree' "$TMP/error"
# Invalid or existing branch names and occupied target paths are rejected.
git branch taken main
if wt rename fix/fifth taken >/dev/null 2>&1; then exit 1; fi
if wt rename fix/fifth 'invalid branch*name' >/dev/null 2>&1; then exit 1; fi
mkdir -p "$TMP/worktrees/repo/fix-occupied"
if wt rename fix/fifth fix/occupied >/dev/null 2>&1; then exit 1; fi
[[ -d "$fifth" && "$(git -C "$fifth" branch --show-current)" == fix/fifth ]]

# If Git cannot move the worktree, the existing branch and directory stay intact.
export REAL_GIT=$(command -v git)
cat > "$TMP/bin/git" <<'WRAPPER'
#!/usr/bin/env bash
if [[ "${FAIL_MOVE:-}" == 1 && "${1-}" == worktree && "${2-}" == move ]]; then
  echo 'fatal: Invalid cross-device link' >&2
  exit 77
fi
if [[ "${FAIL_BRANCH_RENAME:-}" == 1 && "${1-}" == branch && "${2-}" == -m ]]; then
  echo 'simulated branch rename failure' >&2
  exit 78
fi
exec "$REAL_GIT" "$@"
WRAPPER
chmod +x "$TMP/bin/git"
export PATH="$TMP/bin:$PATH"
if FAIL_MOVE=1 wt rename fix/fifth fix/sixth > /dev/null 2> "$TMP/error"; then exit 1; fi
[[ -d "$fifth" && ! -e "$TMP/worktrees/repo/fix-sixth" ]]
[[ "$(git -C "$fifth" branch --show-current)" == fix/fifth ]]
# If the move succeeds but the branch rename fails, restore the original path.
if FAIL_BRANCH_RENAME=1 wt rename fix/fifth fix/sixth > /dev/null 2> "$TMP/error"; then exit 1; fi
grep -q 'rolled back worktree rename' "$TMP/error"
[[ -d "$fifth" && ! -e "$TMP/worktrees/repo/fix-sixth" ]]
[[ "$(git -C "$fifth" branch --show-current)" == fix/fifth ]]
! git show-ref --verify -q refs/heads/fix/sixth
unset FAIL_MOVE FAIL_BRANCH_RENAME

# Rename worktree where source and new branch resolve to the same folder name.
same=$(wt rename fix/fifth fix-fifth)
[[ "$same" == "$fifth" && -d "$fifth" ]]
[[ "$(git -C "$fifth" branch --show-current)" == fix-fifth ]]

# A branch separator of '/' supports nested destinations.
git config --global wt.separator /
nested=$(wt rename fix-fifth next/nested)
[[ "$nested" == "$TMP/worktrees/repo/next/nested" && -d "$nested" ]]
[[ "$(git -C "$nested" branch --show-current)" == next/nested ]]

# Renames from the main checkout do not move its shell's working directory.
(
  source "$ROOT/shell/wt.bash"
  previous=$PWD
  wt rename next/nested next/again > "$TMP/shell-output"
  [[ "$PWD" == "$previous" ]]
  [[ -s "$TMP/shell-output" ]]
)
echo 'rename tests passed'