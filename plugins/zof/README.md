# zof

Connects Claude Code to your company's Zof through the hosted Zof MCP server at `https://mcp.zof.ai/mcp`. You can ask
whether a pull request may ship, why Zof blocks it, what evidence is missing, and how its test runs went. Every tool is
read-only. You sign in with your own Zof account (`/mcp`, then **zof**, then **Authenticate**), and the connection only
sees the company you pick.

Install in Claude Code:

```
/plugin marketplace add Zof-AI/claude-plugins
/plugin install zof@zof
```

Skills: `/zof:ship-check`, `/zof:explain-block`, `/zof:test-runs`. Set `ZOF_MCP_URL` to use another server address.
Install steps, the tool list and help links are in the marketplace README: https://github.com/Zof-AI/claude-plugins.

Push check: a warn-only `PreToolUse` hook runs on `git push`, `gh pr create` and `gh pr merge`. It adds a reminder
asking Claude to check `zof_check_change` (or `zof_get_release_decision`) first and tell you what Zof requires. It never
blocks a command and makes no network calls. Turn it off with `export ZOF_PUSH_CHECK=off`. Test it with
`sh plugins/zof/tests/pre-push-check.test.sh`.
