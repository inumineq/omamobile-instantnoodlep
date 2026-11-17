<!-- SPDX-License-Identifier: MIT -->
# Active work

One file per running worker, named `<worker>.md`. The first non-heading
line is what `scripts/trail-lite brief` prints, so make it one line:
host, branch, goal. Below it, anything another agent should know before
touching the same files.

- **Start**: add your file in your branch's first commit and push it
  (a draft PR is fine). `brief` on every host then shows it as "pushed,
  not merged", before anything merges.
- **Finish**: delete your file in your final PR, and update
  `docs/agents/state.md` with the result.
- One file per worker, so two workers never edit the same file and never
  conflict here.
