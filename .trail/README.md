<!-- SPDX-License-Identifier: MIT -->
# .trail

What sessions on this repo worked out, kept next to the code so the next
session, on any host and in any agent, starts from it instead of digging
again. The format is [Trail-code](https://github.com/trailhq/Trail-Code)'s,
so the `trail` CLI reads these files as they are if it is ever installed.
Nothing here needs it: they are plain markdown.

- `learnings/`: one file per learning: what was decided, what was tried and
  ruled out, what to watch out for. Front matter: `title`, `author`
  (`<agent> on <host>`), `date`, `id`, `kind`, `status`, and `touches` (the
  paths it is about: read it before changing those). Write one with
  `scripts/trail-lite note`, never by hand-picking an id.

Rules for this repo:

- A learning is a summary, never a transcript or a capture. Device facts
  carry [V]/[I] tags (AGENTS rule 2); no serials, IMEI, MAC addresses or
  emails (rule 4). `scripts/trail-lite lint` checks for those.
- Never edit an existing learning's decision. When one stops holding, add a
  new one with `replaces: <old id>` in its front matter and set the old
  one's `status: replaced`.
- Commit a learning with the change it came from.
