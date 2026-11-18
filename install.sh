#!/usr/bin/env bash
set -euo pipefail

# --- Installation locations (edit these, or override with environment vars) ---
BIN_DIR=${BIN_DIR:-~/.local/bin/wt}
BASH_COMPL_DIR=${BASH_COMPL_DIR:-~/.local/share/bash-completion/completions}
ZSH_COMPL_DIR=${ZSH_COMPL_DIR:-~/.local/share/zsh-completion/completions}
MAN_DIR=${MAN_DIR:-~/.local/share/man/man1}
BASH_RC=${BASH_RC:-~/.bashrc}
ZSH_RC=${ZSH_RC:-~/.zshrc}
# -------------------------------------------------------------------------

fail() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

expand_home() {
  case "$1" in
    '~') printf '%s' "$HOME" ;;
    '~/'*) printf '%s/%s' "$HOME" "${1:2}" ;;
    *) printf '%s' "$1" ;;
  esac
}

absolute_path() {
  local path
  path=$(expand_home "$1")
  [[ "$path" == /* && "$path" != *$'\n'* && "$path" != *$'\r'* ]] || fail "expected an absolute path: $1"
  printf '%s' "$path"
}

ensure_source() {
  local rc=$1 target=$2 line
  printf -v line 'source %q' "$target"
  [[ ! -d "$rc" ]] || fail "shell configuration is a directory: $rc"
  mkdir -p "$(dirname "$rc")"
  if [[ -f "$rc" ]] && grep -Fqx -- "$line" "$rc"; then
    printf 'Already configured: %s\n' "$rc"
    return
  fi
  # Include a separating newline even if the previous last line had none.
  printf '\n%s\n' "$line" >> "$rc"
  printf 'Updated: %s\n' "$rc"
}

main() {
  local repo_dir bash_script zsh_script path
  repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
  for path in wt shell/wt.bash shell/wt.zsh man/wt.1; do
    [[ -f "$repo_dir/$path" ]] || fail "missing source file: $repo_dir/$path"
  done

  BIN_DIR=$(absolute_path "$BIN_DIR")
  BASH_COMPL_DIR=$(absolute_path "$BASH_COMPL_DIR")
  ZSH_COMPL_DIR=$(absolute_path "$ZSH_COMPL_DIR")
  MAN_DIR=$(absolute_path "$MAN_DIR")
  BASH_RC=$(absolute_path "$BASH_RC")
  ZSH_RC=$(absolute_path "$ZSH_RC")

  bash_script="$BASH_COMPL_DIR/wt.bash"
  zsh_script="$ZSH_COMPL_DIR/wt.zsh"
  mkdir -p "$(dirname "$BIN_DIR")" "$BASH_COMPL_DIR" "$ZSH_COMPL_DIR" "$MAN_DIR"
  install -m 755 "$repo_dir/wt" "$BIN_DIR"
  install -m 644 "$repo_dir/shell/wt.bash" "$bash_script"
  install -m 644 "$repo_dir/shell/wt.zsh" "$zsh_script"
  install -m 644 "$repo_dir/man/wt.1" "$MAN_DIR/wt.1"

  ensure_source "$BASH_RC" "$bash_script"
  ensure_source "$ZSH_RC" "$zsh_script"

  printf '\nInstalled wt to %s\n' "$BIN_DIR"
  printf 'Restart your shell to enable navigation and completion.\n'
  if [[ ":$PATH:" != *":$(dirname "$BIN_DIR"):"* ]]; then
    printf 'Note: add %s to PATH to invoke wt.\n' "$(dirname "$BIN_DIR")"
  fi
}

main "$@"