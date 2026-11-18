# wt — shell Git worktree helper

A Git worktree helper built with **Bash** and small **Bash/Zsh** shell integrations. No Go, TOML parser, Node.js, or Python dependency. Settings live in `git config`.

> **Attribution:** This project is independently implemented in shell and is heavily inspired by [timvw/wt](https://github.com/timvw/wt), the original MIT-licensed Go worktree manager by Tim Van Wassenhove. Its command names, worktree strategies, and user experience informed this project. This is **not** an official fork or affiliated project; see the [original project's license](https://github.com/timvw/wt/blob/main/LICENSE).

## Install

Run the configurable installer from the cloned repository:

```bash
./install.sh
```

Edit the variables at the top of `install.sh`, or override them with environment variables:

```bash
BIN_DIR="$HOME/.local/bin/wt" \
BASH_COMPL_DIR="$HOME/.local/share/bash-completion/completions" \
ZSH_COMPL_DIR="$HOME/.local/share/zsh-completion/completions" \
MAN_DIR="$HOME/.local/share/man/man1" \
./install.sh
```

The installer creates the destination directories, installs the executable as mode 755, and copies the Bash and Zsh shell integration files and manual page as mode 644. It adds a quoted `source` line to `~/.bashrc` and `~/.zshrc` if the exact line is not already present. Both shell startup file paths are configurable using `BASH_RC` and `ZSH_RC`. Re-running the installer updates the installed files without duplicating its startup lines. Restart your shell to activate integration.

`BIN_DIR` is the **full filename** (for example `~/.local/bin/wt`), while the completion and manual settings are directories. If `~/.local/bin` is not on your `PATH`, add it to your shell configuration. If `man wt` cannot find the page, configure `MANPATH` or open it directly with `man -l man/wt.1`.

The completion destinations are for sourcing the shell integration scripts, not automatic discovery by completion managers. The installer sources both scripts explicitly because they also provide the `wt` function for automatic directory navigation.

Without shell integration, the commands still work but cannot change the calling shell's working directory; `wt cd` prints the destination.

## Manual page

The repository includes a standard section 1 man page at [`man/wt.1`](man/wt.1), covering commands, configuration, directory strategies, shell integration, and safety notes.

Install it for your user account:

```bash
mkdir -p ~/.local/share/man/man1
install -m 644 man/wt.1 ~/.local/share/man/man1/wt.1
man wt
```

If `man wt` cannot find it, add `~/.local/share/man` to your `MANPATH`, or view it directly with `man -l man/wt.1`. On Linux, you may need `mandb` to refresh the manual index.

## Commands

```text
wt config [--global|--local]  Interactive wizard; Enter/spaces selects displayed default
wt config show|get|set|unset Inspect or modify wt.* Git config keys
wt clone OWNER/REPO [DEST] Clone under configured repo root
wt create NAME [BASE]     Create new branch/worktree
wt co [BRANCH]            Check out an existing branch into a worktree
wt cd [BRANCH]            Switch to an existing worktree (never creates)
wt sw                     Alias for wt cd
wt ls                     List worktrees
wt status                 Dirty state and upstream ahead/behind for each worktree
wt rm [BRANCH|NAME|PATH]  Remove worktree (Git refuses dirty worktrees)
wt pr [NUMBER|URL]        GitHub pull request (requires gh)
wt mr NUMBER|URL          GitLab merge request (requires glab and jq)
wt copy [BRANCH]          Copy configured untracked/ignored files
wt migrate [--dry-run]    Move nonprimary worktrees to configured layout
wt cleanup --stale        Report inactive or upstream-gone worktrees
wt prune                  Git maintenance
wt info                   Show effective path settings
```

`wt rm` accepts a branch (`fix/do-thing`), a worktree folder name (`fix-do-thing`), or an absolute worktree path. If a name matches multiple worktrees, it refuses to remove anything; use the full path to disambiguate. Bash and Zsh tab completion offers both branch names and worktree folder names for `wt rm` / `wt remove` (for example, typing `wt rm fix` offers `fix/do-thing` and `fix-do-thing`). Source the shell integration script and start a new shell to enable it.

Without arguments, `co`, `cd`, and `rm` use `fzf` if installed, or a numbered prompt. `pr` uses the GitHub CLI for listing/metadata. For generated paths, the script supports the same seven strategy names as the original project.

## Interactive Git configuration

Run `wt config` for a wizard. Empty answers or answers containing only whitespace use the displayed default. The default is the value already set in the selected scope, or the built-in default on first run. `--local` stores settings for just the current Git repository.

```bash
git config --global wt.root ~/.worktrees
git config --global wt.strategy global
git config --global wt.separator -
git config --global --add wt.copy .env
```

`wt config` also sets `wt.repoRoot`, `wt.repoPattern`, and `wt.copyIgnored`, plus multi-valued `wt.copy`, `wt.link`, and `wt.exclude`. A repo can check in `.worktreeinclude` with paths to copy. `wt.pattern` can override standard layouts, and is used by the `custom` strategy.

## Limitations / differences from timvw/wt

- **No hooks, hook trust system, TOML, or Fish integration** (intentionally omitted).
- The source is Bash (macOS system Bash 3.2 or newer), and the Zsh integration invokes the Bash CLI.
- Only common shell path-template variables are implemented (`{.worktreeRoot}`, `{.repo.Main}`, `{.repo.Name}`, `{.branch}`, `{.env.NAME}`, `{.env.NAME:-fallback}`). Clone placement supports `repoRoot`, host, owner, name, and default branch.
- File copy/linking is a small subset of the original. Worktree selection and glob matching use shell rules, not the original's full gitignore matcher; copying does not use reflinks. `wt mr` currently needs an MR argument. JSON output and built-in CI dashboard are not implemented.
- Destination checks prevent writing into the filesystem root, Git metadata, protected user/system configuration paths, or existing checkouts. The script resolves existing and dangling symlinks, rejects already-present destination paths, revalidates after creating parent directories, and confines auto-generated clone paths to `wt.repoRoot`.
- Failed/interrupted `create`/`co` operations attempt to remove **only the newly registered worktree** (including partially copied files). A branch created by that operation is deleted only if its commit hasn't changed. Pre-existing branches are preserved. `migrate` validates its complete plan and attempts to reverse earlier moves if a later move fails.
- **Limits:** These checks do not make filesystem operations atomic or race-free. Concurrent path/symlink changes can defeat preflight checks, and a failed rollback may require manual inspection. Git hooks/config inclusions and all sensitive filesystem paths are not fully audited; this is not a security sandbox or complete replacement for the original Go tool's hardening. Clone failures rely on Git's own cleanup; use trusted configuration and avoid running against actively changing worktrees.

## Testing

```bash
bash tests/test.sh
bash tests/safety.sh
```

## License

MIT. See [LICENSE](LICENSE). Credit to timvw/wt above is retained as attribution to the original design.