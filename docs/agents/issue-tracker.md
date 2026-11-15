<!-- SPDX-License-Identifier: MIT -->
# Issue tracker: GitHub (inumineq/omamobile-instantnoodlep)

Issues, the wayfinder map and its decision tickets for this repo live as
GitHub issues in this private repository. Agents here do not use the `gh`
CLI; they use the `connector_github_app` tools, so the operations below are
written with those. Semantics follow the mattpocock/skills GitHub template.

## Conventions

- **Create an issue**: `connector_github_app.issue_write` with
  `method: "create"`, `title`, `body`, optional `labels` (the REST
  add-labels call creates missing labels), `assignees`, and
  `parent_issue_number` to attach it as a sub-issue in the same call.
- **Read an issue**: `connector_github_app.issue_read` with
  `method: "get" | "get_comments" | "get_labels" | "get_sub_issues"`.
- **List issues**: `connector_github_app.list_issues` with `state`,
  `labels`, `fields`. `connector_github_app.search_issues` for semantic
  queries.
- **Make an issue a sub-issue of a parent**: pass
  `parent_issue_number` on create, or afterwards
  `connector_github_app.sub_issue_write` `method: "add"` with the child's
  database id in `sub_issue_id`. Fallback when sub-issues are unavailable:
  put `Part of #<parent>` at the top of the child body.
- **Blocking**: this connector exposes no native blocked-by dependency
  write, so use the documented fallback: a `Blocked by: #<n>, #<n>` line at
  the top of the child body. A ticket is unblocked when every blocker is
  closed. (Upstream template prefers native dependencies on GitHub; if a
  connector tool for `dependencies/blocked_by` appears, switch to it.)
- **Comment / label / close**: `connector_github_app.add_issue_comment`,
  `issue_write` `method: "update"` with `labels` / `state: "closed"` /
  `assignees`.
- GitHub shares one number space across issues and PRs, so a bare `#42` may
  be either.

## When a skill says "publish to the issue tracker"

Create a GitHub issue in this repo.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above.

## Wayfinding operations

Used by `/wayfinder` (mattpocock/skills). The **map** is a single issue with
**child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the
  Destination / Notes / Decisions-so-far / Not-yet-specified / Out-of-scope
  body. Create with `issue_write` `method: "create"`,
  `labels: ["wayfinder:map"]`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue
  (`parent_issue_number` on create, or `sub_issue_write` afterwards).
  Fallback: a task list in the map body plus `Part of #<map>` at the top of
  the child body. Labels: `wayfinder:<type>` (`research` / `prototype` /
  `grilling` / `task`). Once claimed, the ticket is assigned to the
  driving dev (`issue_write` `method: "update"`, `assignees: [...]`).
- **Blocking**: `Blocked by: #<n>` line at the top of the child body (see
  Conventions). A ticket is unblocked when all its blockers are closed.
- **Frontier query**: list the map's open children
  (`issue_read` `method: "get_sub_issues"` on the map, or
  `list_issues` `state: "open"` with the `wayfinder:*` labels), drop any
  with an open blocker (unclosed issue in its `Blocked by` line) or an
  assignee; first in map order wins.
- **Claim**: `issue_write` `method: "update"` with `assignees: [<dev>]`,
  the session's first write on the ticket.
- **Resolve**: `add_issue_comment` with the answer, then `issue_write`
  `method: "update"` `state: "closed"`, then append a one-line pointer to
  the map's Decisions-so-far (`issue_write` update of the map body).

Refer to maps and tickets by their **title** in narration and in the map body,
never by a bare `#42`.
