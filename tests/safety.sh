#!/usr/bin/env bash
set -euo pipefail
WT="$(cd "$(dirname "$0")/.." && pwd)/wt"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME/.config" "$HOME/.ssh" "$T/repo" "$T/bin"
cd "$T/repo"
git init -q -b main
git config user.email tests@example.com
git config user.name Tests
echo initial > tracked; git add tracked; git commit -qm initial
fail_guard() { if "$@" >"$T/output" 2>"$T/error"; then echo "expected rejection: $*" >&2; exit 1; fi; }
git config --global wt.root "$HOME/.config/worktrees"
fail_guard "$WT" create unsafe
git config --global wt.strategy custom
git config --global wt.pattern "$HOME/.ssh/{.branch}"
fail_guard "$WT" create unsafe
git config --global wt.pattern "$T/alias/{.branch}"
ln -s "$T/repo/.git" "$T/alias"
fail_guard "$WT" create unsafe
git config --global wt.pattern "$T/repo/{.branch}"
fail_guard "$WT" create unsafe
git config --global wt.strategy inside-dotdir
git config --global --unset wt.pattern
"$WT" create nested > "$T/path"
[[ -d "$T/repo/.worktrees/nested" ]]
"$WT" rm nested
echo .env >>.gitignore; git add .gitignore; git commit -qm ignore-env
echo VALUE=x >.env
git config --local wt.copy .env
git config --global wt.strategy global
git config --global wt.root "$T/safe"
printf '#!/bin/sh\nexit 27\n' > "$T/bin/cp"; chmod +x "$T/bin/cp"
export PATH="$T/bin:$PATH"
fail_guard "$WT" create rollback
[[ ! -e "$T/safe/repo/rollback" ]]
! git show-ref --verify -q refs/heads/rollback
git branch existing HEAD
fail_guard "$WT" co existing
git show-ref --verify -q refs/heads/existing
rm "$T/bin/cp"
fail_guard "$WT" clone "$T/repo" "$HOME/.config/clone"
"$WT" clone "$T/repo" "$T/clone" >/dev/null
[[ -d "$T/clone/.git" ]]
git config --global wt.repoRoot "$T/repo-root"
git config --global wt.repoPattern '{.repoRoot}/../../escape/{.branch}'
fail_guard "$WT" clone "$T/repo"
git config --global --unset wt.repoPattern
"$WT" create first >/dev/null
"$WT" create second >/dev/null
git config --global wt.strategy sibling-repo
export WT_REAL_GIT="$(command -v git)"
cat > "$T/bin/git" <<'WRAPPER'
#!/usr/bin/env bash
if [[ "${WT_FAIL_MIGRATE:-}" == 1 && "${1:-}" == worktree && "${2:-}" == move && "${4:-}" == *repo-second ]]; then exit 47; fi
exec "$WT_REAL_GIT" "$@"
WRAPPER
chmod +x "$T/bin/git"
export WT_FAIL_MIGRATE=1
fail_guard "$WT" migrate
unset WT_FAIL_MIGRATE
[[ -d "$T/safe/repo/first" && -d "$T/safe/repo/second" ]]
[[ ! -e "$T/repo-first" && ! -e "$T/repo-second" ]]
"$WT" migrate >/dev/null
[[ -d "$T/repo-first" && -d "$T/repo-second" ]]
echo "Safety tests passed"
