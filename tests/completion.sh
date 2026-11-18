#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
export GIT_CONFIG_GLOBAL="$TEMP/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
export HOME="$TEMP/home"
mkdir -p "$HOME" "$TEMP/repo"
cd "$TEMP/repo"
git init -q -b main
git config user.email tests@example.com
git config user.name Tests
printf 'hello\n' > tracked.txt
git add tracked.txt
git commit -qm initial
git config --global wt.root "$TEMP/worktrees"
git config --global wt.separator -
"$ROOT/wt" create fix/do-thing >/dev/null
git branch fix/not-checked-out
git worktree add -q -b unrelated-branch "$TEMP/fix-special-folder" main
git worktree add -q -b another-branch "$TEMP/fix folder with spaces" main

source "$ROOT/shell/wt.bash"
COMP_WORDS=(wt rm fix)
COMP_CWORD=2
_wt_complete
[[ " ${COMPREPLY[*]} " == *' fix/do-thing '* ]]
[[ " ${COMPREPLY[*]} " == *' fix-do-thing '* ]]
[[ " ${COMPREPLY[*]} " == *' fix-special-folder '* ]]
[[ " ${COMPREPLY[*]} " != *' fix/not-checked-out '* ]]
COMP_WORDS=(wt rm fix/)
_wt_complete
[[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == fix/do-thing ]]
COMP_WORDS=(wt rm fix-)
_wt_complete
[[ " ${COMPREPLY[*]} " == *' fix-do-thing '* ]]
[[ " ${COMPREPLY[*]} " == *' fix-special-folder '* ]]
COMP_WORDS=(wt remove fix)
_wt_complete
[[ " ${COMPREPLY[*]} " == *' fix/do-thing '* ]]
[[ " ${COMPREPLY[*]} " == *' fix-do-thing '* ]]
COMP_WORDS=(wt rm 'fix folder')
_wt_complete
[[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == 'fix folder with spaces' ]]

# Existing-worktree commands complete both checked-out branches and folder names.
for action in cd sw switch copy rm remove rename; do
  COMP_WORDS=(wt "$action" fix)
  _wt_complete
  [[ " ${COMPREPLY[*]} " == *' fix/do-thing '* ]]
  [[ " ${COMPREPLY[*]} " == *' fix-do-thing '* ]]
  [[ " ${COMPREPLY[*]} " == *' fix-special-folder '* ]]
  [[ " ${COMPREPLY[*]} " != *' fix/not-checked-out '* ]]
  COMP_WORDS=(wt "$action" fix/)
  _wt_complete
  [[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == fix/do-thing ]]
  COMP_WORDS=(wt "$action" 'fix folder')
  _wt_complete
  [[ ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == 'fix folder with spaces' ]]
done
# Checkout still completes branches, including ones without an existing worktree.
COMP_WORDS=(wt co fix)
_wt_complete
[[ " ${COMPREPLY[*]} " == *' fix/not-checked-out '* ]]
[[ " ${COMPREPLY[*]} " != *' fix-special-folder '* ]]

# The second rename argument is a new branch name, not an existing-worktree lookup.
COMP_WORDS=(wt rename fix/do-thing new)
COMP_CWORD=3
_wt_complete
[[ ${#COMPREPLY[@]} -eq 0 ]]

if command -v zsh >/dev/null 2>&1; then
  out=$(zsh -fc "source '$ROOT/shell/wt.zsh'; _wt_worktree_candidates")
  [[ "$out" == *'fix/do-thing'* && "$out" == *'fix-do-thing'* ]]
fi
echo 'completion tests passed'
