#!/bin/sh
# Each check is an eval'd string, so single-quoted expansions and "unused" variables are intended.
# shellcheck disable=SC2016,SC2034
# POSIX tests for the git pre-push installer and the Cursor hook. Temp repos go under $ZOF_TEST_TMP (or mktemp).
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
installer="$root/git/install-git-hook.sh"
cursor_hook="$root/cursor/hooks/zof-push-check.sh"

base=${ZOF_TEST_TMP:-$(mktemp -d)}
mkdir -p "$base"
work=$(mktemp -d "$base/run.XXXXXX")
pass=0
fail=0

ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
no() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else no "$1"; fi; }

new_repo() {
  d="$work/$1"
  git init -q "$d"
  git -C "$d" config user.email t@example.com
  git -C "$d" config user.name t
  printf '%s' "$d"
}

# --- git hook: prints, exits 0, opt-out -------------------------------------------------------
r=$(new_repo plain)
(cd "$r" && sh "$installer" >/dev/null 2>&1)
hook="$r/.git/hooks/pre-push"
check "installer writes an executable pre-push hook" '[ -x "$hook" ]'
out=$(cd "$r" && printf '' | "$hook" origin https://example.invalid 2>&1 >/dev/null); rc=$?
check "hook exits 0" '[ "$rc" -eq 0 ]'
check "hook prints the reminder to stderr" 'printf "%s" "$out" | grep -q "zof_check_change"'
out_stdout=$(cd "$r" && printf '' | "$hook" origin x 2>/dev/null)
check "hook prints nothing to stdout" '[ -z "$out_stdout" ]'
out=$(cd "$r" && printf '' | ZOF_PUSH_CHECK=off "$hook" origin x 2>&1); rc=$?
check "ZOF_PUSH_CHECK=off silences the hook" '[ -z "$out" ] && [ "$rc" -eq 0 ]'

# --- installer: idempotent, chains a foreign hook ---------------------------------------------
r=$(new_repo chain)
h="$r/.git/hooks/pre-push"
mkdir -p "$r/.git/hooks"
printf '#!/bin/sh\necho old-hook-ran "$1" >&2\nread line; echo "stdin:$line" >&2\nexit 7\n' >"$h"
chmod +x "$h"
cp "$h" "$work/foreign"
(cd "$r" && sh "$installer" >/dev/null 2>&1 && sh "$installer" >/dev/null 2>&1)
check "foreign hook backed up" 'cmp -s "$h.zof-backup" "$work/foreign"'
check "installed hook is ours, not the old hook body" '[ "$(grep -c zof-push-check "$h")" -ge 1 ] && ! grep -q old-hook-ran "$h"'
first=$(cat "$h")
(cd "$r" && sh "$installer" >/dev/null 2>&1)
check "install is idempotent (same hook bytes)" '[ "$(cat "$h")" = "$first" ]'
check "no second backup created" '[ ! -e "$h.zof-backup.zof-backup" ] && [ "$(ls "$r/.git/hooks" | grep -c zof-backup)" -eq 1 ]'
out=$(cd "$r" && printf 'refs/heads/main abc refs/heads/main def\n' | "$h" origin x 2>&1); rc=$?
check "chained hook runs with args and stdin" 'printf "%s" "$out" | grep -q "old-hook-ran origin" && printf "%s" "$out" | grep -q "stdin:refs/heads/main abc"'
check "chained hook exit status is kept" '[ "$rc" -eq 7 ]'
check "reminder still shown when chaining" 'printf "%s" "$out" | grep -q zof_check_change'
out=$(cd "$r" && printf 'x\n' | ZOF_PUSH_CHECK=off "$h" origin x 2>&1)
check "opt-out still runs the chained hook" 'printf "%s" "$out" | grep -q old-hook-ran && ! printf "%s" "$out" | grep -q zof_check_change'

# --- uninstall restores the old hook ----------------------------------------------------------
(cd "$r" && sh "$installer" --uninstall >/dev/null 2>&1)
check "uninstall restores the foreign hook" 'cmp -s "$h" "$work/foreign" && [ ! -e "$h.zof-backup" ]'
(cd "$r" && sh "$installer" --uninstall >/dev/null 2>&1); rc=$?
check "uninstall twice is safe and leaves the foreign hook" '[ "$rc" -eq 0 ] && cmp -s "$h" "$work/foreign"'
r2=$(new_repo uninstall-plain)
(cd "$r2" && sh "$installer" >/dev/null 2>&1 && sh "$installer" --uninstall >/dev/null 2>&1)
check "uninstall with no old hook removes ours" '[ ! -e "$r2/.git/hooks/pre-push" ]'

# --- core.hooksPath ---------------------------------------------------------------------------
r=$(new_repo hookspath)
git -C "$r" config core.hooksPath .githooks
mkdir -p "$r/sub/dir"
(cd "$r/sub/dir" && sh "$installer" >/dev/null 2>&1)
check "core.hooksPath (relative) is respected from a subdirectory" '[ -x "$r/.githooks/pre-push" ] && [ ! -e "$r/.git/hooks/pre-push" ]'
abs="$work/shared-hooks"
mkdir -p "$abs"
printf '#!/bin/sh\nexit 0\n' >"$abs/pre-push"
chmod +x "$abs/pre-push"
git -C "$r" config core.hooksPath "$abs"
(cd "$r" && sh "$installer" >/dev/null 2>&1)
check "core.hooksPath (absolute) is respected and chains" 'grep -q zof-push-check "$abs/pre-push" && [ -e "$abs/pre-push.zof-backup" ]'

# --- installer outside a repo fails cleanly ---------------------------------------------------
mkdir -p "$work/not-a-repo"
(cd "$work/not-a-repo" && GIT_CEILING_DIRECTORIES="$work" sh "$installer" >/dev/null 2>&1); rc=$?
check "installer outside a git repo exits non-zero" '[ "$rc" -ne 0 ]'

# --- Cursor hook --------------------------------------------------------------------------------
json_ok() { command -v python3 >/dev/null 2>&1 || return 0; printf '%s' "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("permission")=="allow" else 1)' 2>/dev/null; }
out=$(printf '{"command":"git push origin HEAD","cwd":"/x","hook_event_name":"beforeShellExecution"}' | sh "$cursor_hook"); rc=$?
check "cursor: push gets allow + reminder, exit 0" '[ "$rc" -eq 0 ] && json_ok "$out" && printf "%s" "$out" | grep -q zof_check_change'
out=$(printf '{"command":"gh pr create --fill"}' | sh "$cursor_hook")
check "cursor: gh pr create gets the reminder" 'json_ok "$out" && printf "%s" "$out" | grep -q agent_message'
out=$(printf '{"command":"ls -la"}' | sh "$cursor_hook"); rc=$?
check "cursor: other commands get a bare allow" '[ "$rc" -eq 0 ] && [ "$out" = "{\"permission\":\"allow\"}" ]'
out=$(printf '{"command":"git push"}' | ZOF_PUSH_CHECK=off sh "$cursor_hook")
check "cursor: ZOF_PUSH_CHECK=off gives a bare allow" '[ "$out" = "{\"permission\":\"allow\"}" ]'
out=$(printf 'not json' | sh "$cursor_hook"); rc=$?
check "cursor: odd input still allows" '[ "$rc" -eq 0 ] && [ "$out" = "{\"permission\":\"allow\"}" ]'
out=$(sh "$cursor_hook" </dev/null)
check "cursor: empty input still allows" '[ "$out" = "{\"permission\":\"allow\"}" ]'
if command -v python3 >/dev/null 2>&1; then
  check "cursor: hooks.json is valid JSON with version 1" 'python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d[\"version\"]==1; assert d[\"hooks\"][\"beforeShellExecution\"][0][\"command\"]" "$root/cursor/hooks.json"'
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
