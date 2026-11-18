# Source this file from ~/.bashrc (after placing wt on PATH).
wt() {
  case "${1-}" in
    cd|sw|co|checkout|create|clone|pr|mr)
      local destination
      destination=$(command wt --print-path "$@") || return $?
      [[ -n "$destination" ]] && builtin cd -- "$destination"
      ;;
    *) command wt "$@" ;;
  esac
}
# Complete checked-out branch names and worktree directory names for removal.
_wt_remove_candidates() {
  local line path
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      'worktree '*)
        path=${line#worktree }
        printf '%s\n' "${path##*/}" ;;
      'branch refs/heads/'*)
        printf '%s\n' "${line#branch refs/heads/}" ;;
    esac
  done < <(command git worktree list --porcelain 2>/dev/null) | LC_ALL=C sort -u
}
_wt_complete() {
  local cmd="${COMP_WORDS[1]-}" cur="${COMP_WORDS[COMP_CWORD]-}" opts
  if (( COMP_CWORD == 1 )); then
    opts='config clone create co cd sw ls status rm remove pr mr copy migrate cleanup prune info version help'
  else
    case "$cmd" in
      co|create) opts="$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)" ;;
      rm|remove)
        local candidate
        COMPREPLY=()
        while IFS= read -r candidate; do
          [[ "$candidate" == "$cur"* ]] && COMPREPLY+=("$candidate")
        done < <(_wt_remove_candidates)
        return 0 ;;
      cd|sw|switch|copy) opts="$(command git worktree list --porcelain 2>/dev/null | sed -n 's|^branch refs/heads/||p')" ;;
      config) opts='show get set unset --global --local' ;;
      *) opts='';;
    esac
  fi
  COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}
complete -F _wt_complete wt
