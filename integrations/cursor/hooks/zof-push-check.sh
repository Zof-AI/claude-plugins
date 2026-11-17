#!/bin/sh
# Cursor beforeShellExecution hook: always answers "allow"; on a push or PR command it adds Zof's reminder.
# No network calls. Turn it off with ZOF_PUSH_CHECK=off. Odd input still gets a plain allow.

allow='{"permission":"allow"}'

case "${ZOF_PUSH_CHECK:-}" in off | OFF | 0 | false | no) printf '%s\n' "$allow"; exit 0 ;; esac

input=$(cat 2>/dev/null) || input=''
# Matched without a JSON parser (jq is not guaranteed); a false positive only adds a reminder.
if printf '%s' "$input" | grep -Eq '(^|[^[:alnum:]_./-])(git( +-[^ ]+( +[^ -][^ ]*)?)* +push|gh +pr +(create|merge))([^[:alnum:]_-]|$)' 2>/dev/null; then
  agent='This command pushes code or opens/merges a pull request. Zof is the release policy check for this repo. Before running it, call the Zof MCP tool zof_check_change for this repo and HEAD (when it is available), or zof_get_release_decision for the open pull request, and tell the user what Zof says is required or missing. This is advice only: Zof does not block this command, and the Zof / Control check on the pull request still enforces the merge. If the Zof tools are unavailable, say so briefly and continue.'
  user='Zof checks this change at the pull request. Ask \"will this ship?\" (Zof MCP tool zof_check_change) or open https://console.zof.ai. Set ZOF_PUSH_CHECK=off to hide this.'
  printf '{"permission":"allow","user_message":"%s","agent_message":"%s"}\n' "$user" "$agent"
else
  printf '%s\n' "$allow"
fi
exit 0
