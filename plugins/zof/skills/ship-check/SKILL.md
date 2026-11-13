---
name: ship-check
description: Check whether the current pull request can ship (merge) according to Zof. Use when the user asks "can this PR ship?", "is this ready to merge?", "will Zof let this through?" or wants a release check before or after pushing.
---

# Can this PR ship?

Ask the `zof` MCP server for its merge answer on this pull request, and report it plainly. Zof's answer comes from its
stored release decision. Never guess it, and never say a change may ship unless Zof answered `ship`.

## Steps

1. **Find the pull request.**
   - Repository: `git remote get-url origin`, turned into `owner/name`.
   - PR number: what the user said, or `gh pr view --json number -q .number` for the current branch. If there is no
     open PR, say so and stop. Zof decides on pull requests, not on local branches.
   - Local head: `git rev-parse HEAD`. Run `git status --short` too, so you can mention uncommitted or unpushed work.
2. **Ask Zof.** Call `zof_get_release_decision` with `repo`, `pr` and `head_sha`. Give either `change_id` or `repo`
   plus `pr`, never both.
3. **Report by `answer`:**
   - `ship`: Zof's stored decision allows it. Say this is advice: the **Zof / Control** check on the PR still enforces
     the merge. Give the `url`.
   - `blocked`: run the `explain-block` skill (or call `zof_explain_block` with the same ref) and give its reasons and
     what unblocks it.
   - `pending`: Zof is still deciding. `code` says why:
     - `caller_head_differs`: your local head is not the head Zof tracks. Push, or check the pushed commit.
     - `not_decided`: verification is running. Show `progress` (stage, done/total, any finished results, failures
       first).
     - `check_pending`: the decision is being published to GitHub.

     Tell the user to keep working, and offer to check again after `check_again_in_s`. Don't sleep or poll in a loop.
   - `unknown`: Zof could not give an answer (`unreadable`, or the change is closed). That is not a pass. Say what
     `code` means and give the `url`.
4. **Keep it short:** answer and reason first, then the link. Quote reason codes as Zof gave them; don't invent remedies.

## Errors

A tool result with `isError: true` carries `{code, detail, retry_after_s?}`:

- `unavailable` or `rate_limited`: say Zof could not answer right now, and when to try again (`retry_after_s`).
- A sign-in error (401): ask the user to run `/mcp`, choose `zof` and Authenticate.
- Anything else: show `detail` as it is.

Never treat an error as "no blockers".
