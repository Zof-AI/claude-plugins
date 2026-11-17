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
| `/zof:run-tests` | "Run the tests in Zof." Lists what can run, shows the cost, and starts a run only after your yes. |

Claude also uses the Zof tools on its own when your question needs them. Every tool is read-only except the three that run tests:

- `zof_check_change`: preview whether a change will ship (read-only, free; a preview, not a decision);
- release: `zof_get_release_decision`, `zof_explain_block`, `zof_get_evidence_status`, `zof_list_decisions`,
  `zof_get_policy_requirements`, `zof_get_change_record`, `zof_replay_decision`;
- console: `zof_list_runs`, `zof_get_run`, `zof_get_test_health`, `zof_list_schedules`, `zof_get_system_graph`,
  `zof_get_reports`, `zof_ask_copilot`;
- run tests: `zof_list_available_tests` (what Zof can run), `zof_run_tests` (two steps: a preview with the commit and
  estimated credits plus a single-use confirm token, then the run once you say yes), `zof_cancel_run`.

Running tests needs the **Run tests** permission (OAuth scope `zof:run`). If you connected before it existed, run
`/mcp`, choose `zof`, and reconnect to grant it.

A `ship` answer is advice. The **Zof / Control** check on the pull request still enforces the merge.

## Use Zof with any coding agent

The Zof MCP server works in any agent that speaks MCP. These remind the agent, or the person at the terminal, to check
with Zof before a push. None of them blocks anything or makes network calls.

**Git (any tool, any person).** A `pre-push` hook prints a short reminder on every `git push` and always lets it
through. Run inside your repository (it respects `core.hooksPath`; the URL is pinned to a reviewed commit):

```
curl -fsSL https://raw.githubusercontent.com/Zof-AI/claude-plugins/e4c48d45941195bf5e82ce4e7971427cc36cdd2f/integrations/git/install-git-hook.sh | sh
```

It only installs where no `pre-push` hook exists. If you already have one, or use husky, lefthook or pre-commit, it
changes nothing and prints one line to add near the top of your own hook or config. Add `sh -s -- --uninstall` to remove it, and
set `ZOF_PUSH_CHECK=off` to silence it.

**Cursor.** Copy `integrations/cursor/rules/zof.mdc` to `.cursor/rules/zof.mdc` in your repository. Before a push or a
pull request, the agent asks Zof (`zof_check_change`) and tells you what is required or missing. Cursor also reads
`AGENTS.md`, so the next item works there too.

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
