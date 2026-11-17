# zof

Connects Claude Code to your company's Zof through the hosted Zof MCP server at `https://mcp.zof.ai/mcp`. You can ask
whether a pull request may ship, why Zof blocks it, what evidence is missing, and how its test runs went. Most tools are
read-only; running tests needs the separate **Run tests** permission (reconnect zof in `/mcp` to grant it). You sign in with your own Zof account (`/mcp`, then **zof**, then **Authenticate**), and the connection only
sees the company you pick.

Install in Claude Code:

```
/plugin marketplace add Zof-AI/claude-plugins
/plugin install zof@zof
```

Skills: `/zof:ship-check`, `/zof:explain-block`, `/zof:test-runs`, `/zof:run-tests`. Set `ZOF_MCP_URL` to use another server address.
Install steps, the tool list and help links are in the marketplace README: https://github.com/Zof-AI/claude-plugins.
