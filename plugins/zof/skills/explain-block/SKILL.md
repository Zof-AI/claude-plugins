---
name: explain-block
description: Explain why Zof blocks a pull request or release, and what would unblock it. Use when the user asks "why is my release blocked?", "why did Zof fail this PR?", "what evidence is missing?" or "what do I need to do to get this merged?".
---

# Why is my release blocked?

Explain Zof's blocking decision in plain words, with the exact steps that would unblock it. Every fact comes from the
`zof` MCP tools. Policy is decided in Zof, so never suggest changing or skipping it from here.

## Steps

1. **Find the change.** Use the ref the user gave (`change_id`, or `repo` as `owner/name` plus `pr`). If they gave
   neither, take the repository from `git remote get-url origin` and the PR from `gh pr view --json number -q .number`.
2. **Read the block.** Call `zof_explain_block` with that ref.
   - `decided: false`: there is no decision for this head yet. Say that this is not a pass, and offer the `ship-check`
     skill to see its progress.
   - Otherwise give `verdict` and each reason, using `texts.reasons[<code>]` for the sentence. List `unblock`
     remedies with their `texts.remedies[<action>]` sentences.
3. **Find what's missing.** Call `zof_get_evidence_status` with the same ref.
   - List each requirement whose `status` isn't satisfied, with `blocking` true first.
   - `requirements_recorded: false` means the decision predates recorded requirements. Say "not recorded", never
     "nothing missing".
   - An evidence part with reason `evidence_unavailable` could not be read. Say so.
4. **If tests are the problem,** call `zof_list_runs` with `repo` (and `status: "failed"` if useful), then `zof_get_run`
   on the latest relevant run. Point at the failing tests, and offer to fix them in this repository.
5. **If the user asks why a rule applies,** call `zof_get_policy_requirements` with the ref, and quote the rule's `key`,
   `intent` and whether it is `blocking` or `advisory`.
6. **Answer** in this order:
   - a one-line summary;
   - the blocking reasons;
   - what to do next, as a short numbered list;
   - the console `url`.

## Rules

- Quote Zof's codes and sentences. Don't paraphrase a reason into a different one, and don't invent remedies.
- An approval or a waiver is given in the Zof console by the people the policy names; you can't grant it. Say who has
  to act if the remedy says so.
- `zof_replay_decision` (with the `decision_id`) proves the stored decision follows from its inputs. Use it only when
  the user doubts the decision.
- On a tool error (`isError: true`), report `code` and `detail`, and never conclude the change is unblocked.
