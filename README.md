# Zof plugins for Claude Code

The `zof` plugin connects Claude Code to your company's Zof, through the hosted Zof MCP server ("Zof for coding
agents"). From your terminal you can ask whether a pull request may ship, why it's blocked, what evidence is missing,
and how its test runs went. Every tool reads only, and you sign in with your own Zof account.

## Install

In Claude Code:

```
/plugin marketplace add Zof-AI/claude-plugins
/plugin install zof@zof
```

Then run `/mcp`, choose **zof** and **Authenticate**. Your browser opens Zof's sign-in. Pick the company to connect;
the connection only ever sees that company.

From a shell, the same steps are `claude plugin marketplace add Zof-AI/claude-plugins`, then
`claude plugin install zof@zof`, then `claude mcp login zof`.

## What you get

| Skill | Ask it |
| --- | --- |
| `/zof:ship-check` | "Can this PR ship?" Gives Zof's merge answer for the current pull request (ship, blocked, pending or unknown), with progress while it verifies. |
| `/zof:explain-block` | "Why is my release blocked?" Gives the blocking reasons, the missing evidence and what unblocks it. |
| `/zof:test-runs` | "Did my tests pass in Zof?" Gives the latest runs, the failing results and help fixing them. |

Claude also uses the Zof tools on its own when your question needs them. Every tool is read-only:

- release: `zof_get_release_decision`, `zof_explain_block`, `zof_get_evidence_status`, `zof_list_decisions`,
  `zof_get_policy_requirements`, `zof_get_change_record`, `zof_replay_decision`;
- console: `zof_list_runs`, `zof_get_run`, `zof_get_test_health`, `zof_list_schedules`, `zof_get_system_graph`,
  `zof_get_reports`, `zof_ask_copilot`.

A `ship` answer is advice. The **Zof / Control** check on the pull request still enforces the merge.

## Use Zof with any coding agent

The Zof MCP server works in any agent that speaks MCP. These add a reminder to check with Zof before a push, for every
tool and for people at the terminal. Each is warn-only, makes no network calls and is turned off with
`ZOF_PUSH_CHECK=off`.

**Git (any tool, any person).** A `pre-push` hook prints a short reminder on every `git push` and never blocks it. It
keeps any hook you already have and runs it after. Run inside your repository (respects `core.hooksPath`):

```
curl -fsSL https://raw.githubusercontent.com/Zof-AI/claude-plugins/main/integrations/git/install-git-hook.sh | sh
```

To remove it and restore your old hook, run the same command with `sh -s -- --uninstall`.

**Cursor.** Copy `integrations/cursor/hooks.json` to `.cursor/hooks.json` and `integrations/cursor/hooks/` to
`.cursor/hooks/` in your repository. On `git push` and `gh pr create`/`merge` the hook allows the command and asks the
agent to call `zof_check_change` first.

**Codex and other agents that read `AGENTS.md`.** Paste `integrations/codex/AGENTS.md` into your repository's
`AGENTS.md`. It tells the agent to ask Zof (`zof_check_change`) before a push or a pull request and to report what is
required or missing.

## Server address

The plugin connects to `https://mcp.zof.ai/mcp`. To use another address, set `ZOF_MCP_URL` before you start Claude
Code. For example, to use the console address:

```
export ZOF_MCP_URL=https://console.zof.ai/api/mcp
```

Both addresses are the same server, and a sign-in on one works on the other.

## Headless agents (CI)

A company admin can create a read-only agent token in Zof (Settings, Connected tools). Add the server with the token
as a header instead of the plugin's sign-in:

```
claude mcp add --transport http zof https://mcp.zof.ai/mcp --header "Authorization: Bearer $ZOF_AGENT_TOKEN"
```

Keep the token in your CI's secret store, never in a file in the repository.

## Help

- Docs: https://console.zof.ai/help
- Support: https://zof.ai/contact
- Privacy: https://zof.ai/legal/privacy
- Terms: https://zof.ai/legal/terms
