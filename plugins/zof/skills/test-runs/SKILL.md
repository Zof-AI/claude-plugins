---
name: test-runs
description: Show this repository's latest Zof test runs and what failed, then help fix it. Use when the user asks "did my tests pass in Zof?", "why did the Zof run fail?", "what's running?" or "how healthy are our tests?".
---

# My Zof test runs

Report what Zof's test runs say about this repository, and turn a failure into a concrete fix in the local code.

## Steps

1. **Repository:** `git remote get-url origin`, as `owner/name`.
2. **Latest runs:** call `zof_list_runs` with `repo`. Use `status: "active"` for what is still running, or
   `status: "failed"` for failures only. Follow `next_cursor` only if the user asks for older runs.
3. **One run in detail:** call `zof_get_run` with its `run_id`.
   - A run still going returns `progress` and `check_again_in_s`. Report the progress, any results already finished
     (failures first), and keep working. Don't wait in a loop.
   - For a failed run (`failed`, `errored` or `timed_out`), list the failing results with their `reason` and
     `analysis`, and the commit the run used. Compare that commit with
     `git rev-parse HEAD`. If they differ, say the failure may already be fixed, or not yet tested.
4. **Fix:** open the failing tests and the code they cover in this repository, explain the likely cause, and offer a
   fix. Run the tests locally if the project has a test command.
5. **Overall health** (only if asked): call `zof_get_test_health` for library, coverage and quality scores. A part with
   `available: false` couldn't be read. Say so, and don't call it zero.

## Notes

- `zof_list_schedules` shows when the next scheduled run is, if the user asks.
- These tools read Zof and change nothing. To start a new run, the user does it in the Zof console or by pushing.
- On a tool error (`isError: true`), report `code` and `detail`. After a 401, ask the user to run `/mcp`, choose `zof`
  and Authenticate.
