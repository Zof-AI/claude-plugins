#!/bin/sh
# Each check is an eval'd string, so single-quoted expansions and "unused" variables are intended.
# shellcheck disable=SC2016,SC2034
# POSIX tests for the git pre-push installer. Temp repos go under $ZOF_TEST_TMP (or mktemp).
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
installer="$root/git/install-git-hook.sh"

base=${ZOF_TEST_TMP:-$(mktemp -d)}
mkdir -p "$base"
work=$(mktemp -d "$base/run.XXXXXX")
pass=0
fail=0

ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
no() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
skip() { printf 'skip %s\n' "$1"; }

new_repo() {
  d="$work/$1"
  git init -q "$d"
  git -C "$d" config user.email t@example.com
  git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init
  git init -q --bare "$work/$1-remote.git"
  git -C "$d" remote add origin "$work/$1-remote.git"
  printf '%s' "$d"
}
sum() { cksum <"$1"; }
# The installer prints the line to add after a blank line on stderr.
printed_line() { sed -n '/^$/{n;p;q;}'; }

# --- empty slot: install, prints, exits 0, opt-out, idempotent ---------------------------------
r=$(new_repo plain)
out=$(cd "$r" && sh "$installer" 2>&1); rc=$?
hook="$r/.git/hooks/pre-push"
check "empty slot: installs an executable pre-push hook" '[ "$rc" -eq 0 ] && [ -x "$hook" ]'
check "hook carries the exact marker line" 'grep -qxF "# zof-push-check v1 (managed)" "$hook"'
out=$(cd "$r" && printf '' | "$hook" origin x 2>&1 >/dev/null); rc=$?
check "hook exits 0 and prints the reminder to stderr" '[ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q zof_check_change'
out_stdout=$(cd "$r" && printf '' | "$hook" origin x 2>/dev/null)
check "hook prints nothing to stdout" '[ -z "$out_stdout" ]'
out=$(cd "$r" && printf '' | ZOF_PUSH_CHECK=off "$hook" origin x 2>&1); rc=$?
check "ZOF_PUSH_CHECK=off silences the hook" '[ -z "$out" ] && [ "$rc" -eq 0 ]'
out=$(cd "$r" && git push origin HEAD:refs/heads/main 2>&1); rc=$?
check "a real git push shows the reminder and succeeds" '[ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q zof_check_change'
first=$(sum "$hook")
(cd "$r" && sh "$installer" >/dev/null 2>&1); rc=$?
check "install again is idempotent" '[ "$rc" -eq 0 ] && [ "$(sum "$hook")" = "$first" ]'
# Counts hook-dir files other than pre-push and git's *.sample files.
extras() {
  n=0
  for x in "$1"/* "$1"/.[!.]*; do
    [ -e "$x" ] || continue
    case "${x##*/}" in pre-push | *.sample) ;; *) n=$((n + 1)) ;; esac
  done
  printf '%s' "$n"
}
check "no backup or extra files are created" '[ "$(extras "$r/.git/hooks")" -eq 0 ]'
(cd "$r" && sh "$installer" --uninstall >/dev/null 2>&1); rc=$?
check "uninstall removes our hook" '[ "$rc" -eq 0 ] && [ ! -e "$hook" ]'
(cd "$r" && sh "$installer" --uninstall >/dev/null 2>&1); rc=$?
check "uninstall twice is safe" '[ "$rc" -eq 0 ]'

# --- a foreign hook is never moved; a marker substring does not count as ours ------------------
r=$(new_repo foreign)
h="$r/.git/hooks/pre-push"
printf '#!/bin/sh\n# mentions zof-push-check v1 (managed) in passing\nexit 7\n' >"$h"
chmod +x "$h"
before=$(sum "$h")
err=$(cd "$r" && sh "$installer" 2>&1 >/dev/null); rc=$?
check "foreign hook: install refused with exit 1" '[ "$rc" -eq 1 ]'
check "foreign hook: left byte-for-byte untouched, nothing renamed" '[ "$(sum "$h")" = "$before" ] && [ "$(extras "$r/.git/hooks")" -eq 0 ]'
line=$(printf '%s\n' "$err" | printed_line)
check "foreign hook: prints a line to add" 'printf "%s" "$line" | grep -q "push-reminder.sh"'
# Appended LAST in a hook without set -e, after a failing command: the push must still be blocked.
r2=$(new_repo foreign-append)
h2="$r2/.git/hooks/pre-push"
printf '#!/bin/sh\necho checks-failed >&2\nfalse\n' >"$h2"
chmod +x "$h2"
err=$(cd "$r2" && sh "$installer" 2>&1 >/dev/null)
printf '%s' "$err" | grep -q "near the top" && near=1 || near=0
check "foreign hook: hint says near the top" '[ "$near" -eq 1 ]'
printf '%s\n' "$(printf '%s\n' "$err" | printed_line)" >>"$h2"
out=$(cd "$r2" && git push origin HEAD:refs/heads/main 2>&1); rc=$?
check "line appended last after a failure: reminder shown, push still blocked" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q zof_check_change && printf "%s" "$out" | grep -q checks-failed'
(cd "$r" && sh "$installer" --uninstall >/dev/null 2>&1)
check "foreign hook: uninstall leaves it alone" '[ "$(sum "$h")" = "$before" ]'

# --- husky v9 layout: refused, untouched, a failing hook still blocks, printed line works -------
r=$(new_repo husky)
mkdir -p "$r/.husky/_"
# Same lookup as husky v9: the wrapper finds the user hook by basename "$0".
printf '#!/bin/sh\ns="$(dirname "$0")/../$(basename "$0")"\n[ -f "$s" ] || exit 0\nexec sh -e "$s" "$@"\n' >"$r/.husky/_/pre-push"
chmod +x "$r/.husky/_/pre-push"
printf 'echo husky-user-hook >&2\nexit 1\n' >"$r/.husky/pre-push"
git -C "$r" config core.hooksPath .husky/_
w_before=$(sum "$r/.husky/_/pre-push"); u_before=$(sum "$r/.husky/pre-push")
err=$(cd "$r" && sh "$installer" 2>&1 >/dev/null); rc=$?
check "husky: install refused with exit 1" '[ "$rc" -eq 1 ]'
check "husky: wrapper and user hook untouched" '[ "$(sum "$r/.husky/_/pre-push")" = "$w_before" ] && [ "$(sum "$r/.husky/pre-push")" = "$u_before" ] && [ "$(ls "$r/.husky/_" | wc -l | tr -d " ")" -eq 1 ]'
out=$(cd "$r" && git push origin HEAD:refs/heads/main 2>&1); rc=$?
check "husky: a failing pre-push still blocks the push" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q husky-user-hook'
line=$(printf '%s\n' "$err" | printed_line)
{ printf '%s\n' "$line"; printf 'exit 1\n'; } >"$r/.husky/pre-push"
out=$(cd "$r" && git push origin HEAD:refs/heads/main 2>&1); rc=$?
check "husky: printed line shows the reminder and the hook still blocks" '[ "$rc" -ne 0 ] && printf "%s" "$out" | grep -q zof_check_change'
printf '%s\n' "$line" >"$r/.husky/pre-push"
out=$(cd "$r" && git push origin HEAD:refs/heads/main 2>&1); rc=$?
check "husky: printed line alone lets the push through" '[ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q zof_check_change'
(cd "$r" && sh "$installer" --uninstall >/dev/null 2>&1)
out=$(cd "$r" && git push origin HEAD:refs/heads/side 2>&1); rc=$?
check "husky: after uninstall the printed line is a silent no-op" '[ "$rc" -eq 0 ] && ! printf "%s" "$out" | grep -q zof_check_change'

# --- lefthook and pre-commit are detected and refused -----------------------------------------
for cfg in lefthook.yml .lefthook.yaml .config/lefthook.yml; do
  r=$(new_repo "lefthook-$(printf '%s' "$cfg" | tr '/.' '__')")
  mkdir -p "$(dirname "$r/$cfg")"
  printf 'pre-push:\n  commands: {}\n' >"$r/$cfg"
  err=$(cd "$r" && sh "$installer" 2>&1 >/dev/null); rc=$?
  check "lefthook ($cfg): refused, no hook written" '[ "$rc" -eq 1 ] && [ ! -e "$r/.git/hooks/pre-push" ] && printf "%s" "$err" | grep -q "zof: { run:"'
done
r=$(new_repo precommit)
printf 'repos: []\n' >"$r/.pre-commit-config.yaml"
err=$(cd "$r" && sh "$installer" 2>&1 >/dev/null); rc=$?
check "pre-commit: refused, no hook written" '[ "$rc" -eq 1 ] && [ ! -e "$r/.git/hooks/pre-push" ]'
if command -v pre-commit >/dev/null 2>&1; then
  line=$(printf '%s\n' "$err" | printed_line)
  printf 'repos:\n%s\n' "$line" >"$r/.pre-commit-config.yaml"
  git -C "$r" add .pre-commit-config.yaml
  out=$(cd "$r" && PRE_COMMIT_HOME="$work/pc-home" pre-commit run --hook-stage pre-push zof-push-check 2>&1); rc=$?
  check "pre-commit: printed entry runs and shows the reminder" '[ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q zof_check_change'
else
  skip "pre-commit: printed entry runs (pre-commit not installed)"
fi

# --- core.hooksPath ---------------------------------------------------------------------------
r=$(new_repo hookspath)
git -C "$r" config core.hooksPath .githooks
mkdir -p "$r/sub/dir"
(cd "$r/sub/dir" && sh "$installer" >/dev/null 2>&1); rc=$?
check "core.hooksPath (relative) is respected from a subdirectory" '[ "$rc" -eq 0 ] && [ -x "$r/.githooks/pre-push" ] && [ ! -e "$r/.git/hooks/pre-push" ]'
(cd "$r" && sh "$installer" --uninstall >/dev/null 2>&1)
check "core.hooksPath: uninstall removes only our file" '[ ! -e "$r/.githooks/pre-push" ]'
abs="$work/shared-hooks"
mkdir -p "$abs"
git -C "$r" config core.hooksPath "$abs"
(cd "$r" && sh "$installer" >/dev/null 2>&1)
check "core.hooksPath (absolute) is respected" 'grep -qxF "# zof-push-check v1 (managed)" "$abs/pre-push"'

# --- installer outside a repo fails cleanly ---------------------------------------------------
mkdir -p "$work/not-a-repo"
(cd "$work/not-a-repo" && GIT_CEILING_DIRECTORIES="$work" sh "$installer" >/dev/null 2>&1); rc=$?
check "installer outside a git repo exits non-zero" '[ "$rc" -ne 0 ]'

# --- Cursor rule --------------------------------------------------------------------------------
rule="$root/cursor/rules/zof.mdc"
check "cursor rule has frontmatter with description and alwaysApply" '[ "$(sed -n 1p "$rule")" = "---" ] && sed -n "2,4p" "$rule" | grep -q "^description: " && sed -n "2,4p" "$rule" | grep -qx "alwaysApply: false"'
check "cursor rule names zof_check_change" 'grep -q zof_check_change "$rule"'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
