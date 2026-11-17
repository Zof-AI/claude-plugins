---
name: run-tests
description: Run tests in Zof for this repository, with a cost preview and the user's yes first. Use when the user asks to "run the tests in Zof", "start a Zof run", "test this commit" or "cancel that run".
---

# Run tests in Zof

Start a Zof test run for this repository. A run uses credits, so it never starts without the user's explicit yes.

## Steps

1. **Repository and commit:** `git remote get-url origin`, as `owner/name`. Use `git rev-parse HEAD` as the `ref`, unless
   the user names a branch or commit. If the commit is not pushed, say Zof can only test pushed commits.
2. **What can run:** call `zof_list_available_tests` with `repo`. Don't guess test names.
3. **Which tests:** if the user didn't say clearly, show the list and ask which to run. A saved test is run with
   `saved_test_id` instead of `tests`.
4. **Preview:** call `zof_run_tests` with `repo`, `ref` and `tests` (or `saved_test_id`), and no `confirm_token`. It
   starts nothing and returns a preview (what runs, the commit, the estimated credits) and a `confirm_token`.
5. **Ask:** show the user the preview in plain words: the tests, the commit and the estimated credits. Ask "Run these?"
   and stop. Wait for the answer.
6. **Run:** only after the user says yes, call `zof_run_tests` again with the same arguments and the `confirm_token`
   from the preview. If the user changes the tests or the commit, preview again for a new token.
7. **Watch:** share the run id and the console link. Call `zof_get_run` with the `run_id`, and call it again after
   `check_again_in_s` seconds while the run is going. Keep other work moving between calls.
8. **Report:** say plainly what passed and failed. For failures, give the `reason` and `analysis`, and offer a fix
   (see `/zof:test-runs`).

## Rules

- Never invent, guess or reuse a `confirm_token`. It is single-use and comes only from the preview call.
- Never call `zof_run_tests` with a token without the user's yes in this conversation for this exact preview.
- To stop a run, call `zof_cancel_run` with the `run_id`. Do it when the user asks.
- If a call says the permission is missing (a 403, or a `code` about the `zof:run` scope), tell the user to run
  `/mcp`, choose `zof`, and reconnect to grant "Run tests". Don't retry.
- On any other tool error (`isError: true`), report `code` and `detail`. If the token is expired or already used, preview
  again and ask again.
