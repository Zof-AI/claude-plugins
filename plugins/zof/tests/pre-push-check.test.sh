#!/bin/sh
# Feeds sample hook JSON to the hook and checks the output. Run: sh plugins/zof/tests/pre-push-check.test.sh
here=$(cd "$(dirname "$0")" && pwd)
hook="$here/../hooks/pre-push-check.sh"
fail=0

run() { printf '%s' "$2" | env $3 sh "$hook"; }
check() { # name input env expect(warn|none)
  out=$(run "$1" "$2" "$3"); rc=$?
  ok=1
  [ "$rc" -eq 0 ] || ok=0
  if [ "$4" = warn ]; then
    case "$out" in *'"hookEventName":"PreToolUse"'*'"additionalContext":"'*zof_check_change*) ;; *) ok=0 ;; esac
    command -v node >/dev/null 2>&1 && { printf '%s' "$out" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' 2>/dev/null || ok=0; }
  else
    [ -z "$out" ] || ok=0
  fi
  if [ "$ok" -eq 1 ]; then echo "PASS $1"; else echo "FAIL $1 (rc=$rc out=$out)"; fail=1; fi
}

bash_in() { printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

check "git push" "$(bash_in 'git push origin feat/x')" X=1 warn
check "git push with flag" "$(bash_in 'git -C repo push -u origin HEAD')" X=1 warn
check "chained push" "$(bash_in 'make check && git push')" X=1 warn
check "gh pr create" "$(bash_in 'gh pr create --fill')" X=1 warn
check "gh pr merge" "$(bash_in 'gh pr merge 12 --merge')" X=1 warn
check "git status (unrelated)" "$(bash_in 'git status')" X=1 none
check "git pushover-ish (unrelated)" "$(bash_in 'echo gitpush')" X=1 none
check "gh pr view (unrelated)" "$(bash_in 'gh pr view 12')" X=1 none
check "non-Bash tool" '{"tool_name":"Edit","tool_input":{"command":"git push"}}' X=1 none
check "malformed json" '{not json git push' X=1 none
check "empty input" '' X=1 none
check "binary-ish input" "$(printf '\001\002\377')" X=1 none
check "disabled by env" "$(bash_in 'git push')" ZOF_PUSH_CHECK=off none

exit $fail
