#!/bin/sh
# Installs (or with --uninstall removes) Zof's warn-only git pre-push reminder in the current repository.
# It only fills an empty pre-push slot and never renames, moves or edits a hook it did not write.
set -eu

marker='# zof-push-check v1 (managed)'
# Hooks run at the top level, so the common git dir resolves there. The line keeps the incoming exit status, so even
# appended after a failing command it never turns a blocked push into a pass; a missing script is skipped.
# shellcheck disable=SC2016 # expanded later, inside the user's hook
call_line='zof_rc=$?; f="$(git rev-parse --git-common-dir)/zof/push-reminder.sh"; [ ! -f "$f" ] || sh "$f"; (exit "$zof_rc")'

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
zdir="$(git rev-parse --git-common-dir)/zof"
script="$zdir/push-reminder.sh"

is_ours() { [ -f "$1" ] && grep -qxF "$marker" "$1" 2>/dev/null; }

if [ "$mode" = uninstall ]; then
  if is_ours "$hook"; then
    rm -f "$hook"
    printf 'zof: removed the reminder hook (%s).\n' "$hook"
  elif [ -e "$hook" ] || [ -L "$hook" ]; then
    printf 'zof: %s is not Zof'"'"'s, so it was left alone; remove any Zof line from it yourself.\n' "$hook"
  fi
  if is_ours "$script"; then
    rm -f "$script"
    rmdir "$zdir" 2>/dev/null || :
    printf 'zof: removed %s.\n' "$script"
  fi
  exit 0
fi

write_reminder() {
  tmp="$1.zof-tmp.$$"
  cat >"$tmp" <<'HOOK'
#!/bin/sh
# zof-push-check v1 (managed)
# Warn-only Zof reminder: never blocks a push, no network calls. Turn it off with ZOF_PUSH_CHECK=off.
case "${ZOF_PUSH_CHECK:-}" in off | OFF | 0 | false | no) exit 0 ;; esac
{
  printf 'zof: Zof checks this change at the pull request.\n'
  printf 'zof: To know first, ask your coding agent "will this ship?" (Zof MCP tool zof_check_change),\n'
  printf 'zof: or open https://console.zof.ai\n'
  printf 'zof: Set ZOF_PUSH_CHECK=off to hide this reminder.\n'
} >&2 2>/dev/null || :
exit 0
HOOK
  chmod +x "$tmp"
  mv "$tmp" "$1"
}

# Refusing still writes our own reminder script under the git dir, so the printed line works at once.
refuse() {
  mkdir -p "$zdir"
  write_reminder "$script"
  printf 'zof: %s No hook was changed.\n' "$1" >&2
  printf 'zof: %s\n\n%s\n\n' "$2" "$3" >&2
  exit 1
}

hooks_path=$(git config --get core.hooksPath 2>/dev/null || :)
case "$hooks_path" in
  *.husky*) refuse "husky manages this repository's hooks." "Add this line near the top of .husky/pre-push:" "$call_line" ;;
esac
for f in lefthook.yml lefthook.yaml .lefthook.yml .lefthook.yaml lefthook.json lefthook.toml \
  .config/lefthook.yml .config/lefthook.yaml; do
  if [ -f "$f" ]; then
    refuse "lefthook manages this repository's hooks ($f)." \
      "Add this command under pre-push: commands: in $f:" "zof: { run: '$call_line' }"
  fi
done
if [ -f .pre-commit-config.yaml ]; then
  q="'"
  refuse "pre-commit manages this repository's hooks (.pre-commit-config.yaml)." \
    "Add this entry under repos: in .pre-commit-config.yaml, then run pre-commit install -t pre-push:" \
    "- {repo: local, hooks: [{id: zof-push-check, name: Zof push reminder, language: system, entry: ${q}sh -c ${q}${q}${call_line}${q}${q}${q}, stages: [pre-push], pass_filenames: false, always_run: true, verbose: true}]}"
fi
if { [ -e "$hook" ] || [ -L "$hook" ]; } && ! is_ours "$hook"; then
  refuse "$hook already exists." "Add this line near the top of it:" "$call_line"
fi

mkdir -p "$dir"
write_reminder "$hook"
printf 'zof: installed the push reminder at %s (turn off with ZOF_PUSH_CHECK=off; remove with --uninstall).\n' "$hook"
