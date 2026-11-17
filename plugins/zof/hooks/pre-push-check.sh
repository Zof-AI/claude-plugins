#!/bin/sh
# Warn-only: adds context asking Claude to check with Zof before a push or PR step. Never blocks, no network.
# Disable with ZOF_PUSH_CHECK=off. Any odd input exits 0 with no output.

case "${ZOF_PUSH_CHECK:-}" in off | OFF | 0 | false | no) exit 0 ;; esac

input=$(cat 2>/dev/null) || exit 0
[ -n "$input" ] || exit 0

# The raw JSON is matched without a parser (jq is not guaranteed); a false positive only adds a reminder.
printf '%s' "$input" | grep -Eq '"tool_name"[[:space:]]*:[[:space:]]*"Bash"' 2>/dev/null || exit 0
printf '%s' "$input" | grep -Eq '(^|[^[:alnum:]_./-])(git( +-[^ ]+( +[^ -][^ ]*)?)* +push|gh +pr +(create|merge))([^[:alnum:]_-]|$)' 2>/dev/null || exit 0

msg='This command pushes code or opens/merges a pull request. Zof is this repo'"'"'s release policy check. Before running it, call the Zof MCP tool zof_check_change for this repo and HEAD (when that tool is available), or zof_get_release_decision for the open pull request. Then tell the user what Zof says is required or missing. This is advice only: Zof does not block this command, and the Zof / Control check on the pull request still enforces the merge. If the Zof tools are unavailable or not signed in, say so briefly and continue. Set ZOF_PUSH_CHECK=off to turn this reminder off.'

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$msg"
exit 0
