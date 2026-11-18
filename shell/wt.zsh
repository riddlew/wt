# Source this file from ~/.zshrc (after placing wt on PATH).
wt() {
  case "${1:-}" in
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
        print -r -- "${path##*/}" ;;
      'branch refs/heads/'*)
        print -r -- "${line#branch refs/heads/}" ;;
    esac
  done < <(command git worktree list --porcelain 2>/dev/null)
}
_wt() {
  local -a commands branches worktrees
  commands=(config clone create co cd sw ls status rm remove pr mr copy migrate cleanup prune info version help)
  if (( CURRENT == 2 )); then
    compadd -- "${commands[@]}"
  else
    case "${words[2]}" in
      co|create)
        branches=("${(@f)$(command git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)}")
        compadd -- "${branches[@]}" ;;
      rm|remove)
        local -a matches
        matches=("${(@f)$(_wt_remove_candidates)}")
        typeset -U matches
        (( ${#matches[@]} )) && compadd -- "${matches[@]}" ;;
      cd|sw|switch|copy)
        worktrees=("${(@f)$(command git worktree list --porcelain 2>/dev/null | sed -n 's|^branch refs/heads/||p')}")
        compadd -- "${worktrees[@]}" ;;
      config) compadd show get set unset --global --local;;
    esac
  fi
}
if (( $+functions[compdef] )); then compdef _wt wt; fi
