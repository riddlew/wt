# Source this file from ~/.bashrc (after placing wt on PATH).
wt() {
  case "${1-}" in
    cd|sw|switch|co|checkout|create|clone|pr|mr)
      local destination
      destination=$(command wt --print-path "$@") || return $?
      [[ -n "$destination" ]] && builtin cd -- "$destination"
      ;;
    rename)
      local previous_root previous_pwd destination
      previous_root=$(command git rev-parse --show-toplevel 2>/dev/null || :)
      previous_pwd=$PWD
      destination=$(command wt --print-path "$@") || return $?
      if [[ -n "$previous_root" && ! -d "$previous_root" && "$previous_pwd" == "$previous_root"* ]]; then
        builtin cd -- "$destination${previous_pwd#"$previous_root"}"
      else
        printf '%s\n' "$destination"
      fi
      ;;
    *) command wt "$@" ;;
  esac
}
# Complete checked-out branch names and worktree directory names.
_wt_worktree_candidates() {
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
    opts='config clone create co cd sw switch ls status rm remove pr mr copy migrate cleanup prune rename info version help'
  else
    case "$cmd" in
      co|checkout|create) opts="$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)" ;;
      rm|remove|cd|sw|switch|copy|rename)
        COMPREPLY=()
        (( COMP_CWORD == 2 )) || return 0
        local candidate
        while IFS= read -r candidate; do
          [[ "$candidate" == "$cur"* ]] && COMPREPLY+=("$candidate")
        done < <(_wt_worktree_candidates)
        return 0 ;;
      config) opts='show get set unset --global --local' ;;
      *) opts='';;
    esac
  fi
  COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}
complete -F _wt_complete wt
