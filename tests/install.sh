#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT

# Running from another directory must still find the repository files.
export HOME="$TEMP/home dir"
mkdir -p "$HOME" "$TEMP/elsewhere"
printf '# bash startup with no ending newline' > "$HOME/.bashrc"
printf '# zsh startup\n' > "$HOME/.zshrc"
cd "$TEMP/elsewhere"
"$ROOT/install.sh" > "$TEMP/install-output"
BIN="$HOME/.local/bin/wt"
BASH_COMPLETION="$HOME/.local/share/bash-completion/completions/wt.bash"
ZSH_COMPLETION="$HOME/.local/share/zsh-completion/completions/wt.zsh"
MAN="$HOME/.local/share/man/man1/wt.1"
[[ -f "$BIN" && -f "$BASH_COMPLETION" && -f "$ZSH_COMPLETION" && -f "$MAN" ]]
mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then
    stat -c '%a' "$1"
  else
    stat -f '%Lp' "$1"
  fi
}
[[ $(mode "$BIN") == 755 ]]
[[ $(mode "$MAN") == 644 ]]
[[ $(mode "$BASH_COMPLETION") == 644 ]]
[[ $(mode "$ZSH_COMPLETION") == 644 ]]
[[ "$(cat "$BIN")" == "$(cat "$ROOT/wt")" ]]
[[ "$(cat "$MAN")" == "$(cat "$ROOT/man/wt.1")" ]]
# Inspect exact source lines through the shell-quoting format used by installer.
printf -v bash_line 'source %q' "$BASH_COMPLETION"
printf -v zsh_line 'source %q' "$ZSH_COMPLETION"
[[ $(grep -Fxc -- "$bash_line" "$HOME/.bashrc") == 1 ]]
[[ $(grep -Fxc -- "$zsh_line" "$HOME/.zshrc") == 1 ]]
bash --noprofile --norc -c 'source "$HOME/.bashrc"; [[ "$(type -t wt)" == function ]]'
"$ROOT/install.sh" > "$TEMP/reinstall-output"
[[ $(grep -Fxc -- "$bash_line" "$HOME/.bashrc") == 1 ]]
[[ $(grep -Fxc -- "$zsh_line" "$HOME/.zshrc") == 1 ]]
# It is possible to override each configurable location without editing the installer.
export BIN_DIR="$TEMP/custom bin/wt"
export BASH_COMPL_DIR="$TEMP/custom bash completions"
export ZSH_COMPL_DIR="$TEMP/custom zsh completions"
export MAN_DIR="$TEMP/custom man"
export BASH_RC="$TEMP/custom bashrc"
export ZSH_RC="$TEMP/custom zshrc"
"$ROOT/install.sh" > "$TEMP/custom-output"
[[ -x "$BIN_DIR" && -f "$BASH_COMPL_DIR/wt.bash" && -f "$ZSH_COMPL_DIR/wt.zsh" && -f "$MAN_DIR/wt.1" ]]
printf -v bash_line 'source %q' "$BASH_COMPL_DIR/wt.bash"
printf -v zsh_line 'source %q' "$ZSH_COMPL_DIR/wt.zsh"
[[ $(grep -Fxc -- "$bash_line" "$BASH_RC") == 1 ]]
[[ $(grep -Fxc -- "$zsh_line" "$ZSH_RC") == 1 ]]
"$ROOT/install.sh" > "$TEMP/custom-again-output"
[[ $(grep -Fxc -- "$bash_line" "$BASH_RC") == 1 ]]
[[ $(grep -Fxc -- "$zsh_line" "$ZSH_RC") == 1 ]]
# Fail quickly rather than write relative to an unintended directory.
if BIN_DIR=relative/wt "$ROOT/install.sh" > /dev/null 2>&1; then
  echo 'ERROR: accepted relative binary path' >&2
  exit 1
fi
printf 'install tests passed\n'