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
_wt() {
  local -a commands branches worktrees
  commands=(config clone create co cd sw ls status rm pr mr copy migrate cleanup prune info version help)
  if (( CURRENT == 2 )); then
    compadd -- "${commands[@]}"
  else
    case "${words[2]}" in
      co|create)
        branches=("${(@f)$(command git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)}")
        compadd -- "${branches[@]}" ;;
      cd|sw|rm|copy)
        worktrees=("${(@f)$(command git worktree list --porcelain 2>/dev/null | sed -n 's|^branch refs/heads/||p')}")
        compadd -- "${worktrees[@]}" ;;
      config) compadd show get set unset --global --local;;
    esac
  fi
}
if (( $+functions[compdef] )); then compdef _wt wt; fi
