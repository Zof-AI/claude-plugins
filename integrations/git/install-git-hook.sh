#!/bin/sh
# Installs (or with --uninstall removes) Zof's warn-only git pre-push reminder in the current repository.
# An existing pre-push hook is kept as pre-push.zof-backup and still runs after the reminder.
set -eu

marker='zof-push-check'

usage() {
  printf 'Usage: install-git-hook.sh [--uninstall]\n'
  printf 'Run inside a git repository. Respects core.hooksPath. Safe to run again.\n'
}

mode=install
case "${1:-}" in
  '') ;;
  --uninstall | uninstall) mode=uninstall ;;
  -h | --help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

top=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'zof: not inside a git working tree; cd into your repository first.\n' >&2
  exit 1
}
cd "$top"
# --git-path honours core.hooksPath; a relative result is relative to the top level we just cd'd to.
dir=$(git rev-parse --git-path hooks)
# shellcheck disable=SC2088 # matches a literal ~ that git left unexpanded
case "$dir" in "~/"*) dir="$HOME/${dir#\~/}" ;; esac
hook="$dir/pre-push"
backup="$hook.zof-backup"

is_ours() { [ -f "$1" ] && grep -q "$marker" "$1" 2>/dev/null; }

if [ "$mode" = uninstall ]; then
  if is_ours "$hook"; then
    rm -f "$hook"
    if [ -e "$backup" ] || [ -L "$backup" ]; then
      mv "$backup" "$hook"
      printf 'zof: removed the reminder and restored your previous pre-push hook (%s).\n' "$hook"
    else
      printf 'zof: removed the reminder (%s).\n' "$hook"
    fi
  else
    printf 'zof: no Zof reminder installed at %s; nothing changed.\n' "$hook"
  fi
  exit 0
fi

mkdir -p "$dir"
if [ -e "$hook" ] || [ -L "$hook" ]; then
  if ! is_ours "$hook"; then
    if [ -e "$backup" ] || [ -L "$backup" ]; then
      printf 'zof: %s already exists; move it aside and run again. Nothing changed.\n' "$backup" >&2
      exit 1
    fi
    mv "$hook" "$backup"
    printf 'zof: kept your existing pre-push hook as %s; it still runs after the reminder.\n' "$backup"
  fi
fi

tmp="$hook.zof-tmp.$$"
cat >"$tmp" <<'HOOK'
#!/bin/sh
# zof-push-check: warn-only Zof reminder; never blocks a push and makes no network calls.
# Turn it off with ZOF_PUSH_CHECK=off. Remove it with: install-git-hook.sh --uninstall
case "${ZOF_PUSH_CHECK:-}" in
  off | OFF | 0 | false | no) ;;
  *)
    {
      printf 'zof: Zof checks this change at the pull request.\n'
      printf 'zof: To know first, ask your coding agent "will this ship?" (Zof MCP tool zof_check_change),\n'
      printf 'zof: or open https://console.zof.ai\n'
      printf 'zof: Set ZOF_PUSH_CHECK=off to hide this reminder.\n'
    } >&2 2>/dev/null || :
    ;;
esac
# Chain to the hook that was here before Zof's, with the same arguments and stdin; its answer decides the push.
prev="$(dirname "$0")/pre-push.zof-backup"
if [ -x "$prev" ]; then
  exec "$prev" "$@"
fi
exit 0
HOOK
chmod +x "$tmp"
mv "$tmp" "$hook"
printf 'zof: installed the push reminder at %s (turn off with ZOF_PUSH_CHECK=off; remove with --uninstall).\n' "$hook"
