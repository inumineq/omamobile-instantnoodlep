<!-- SPDX-License-Identifier: MIT -->
# Kona root series (draft, GPL-2.0 kernel patches)

[V] `0001`–`0003` are generated from `instantnoodlep-k3-kona` in
`~/src/l-k3k`; `0000` is an unsent cover-letter draft.
The source and validation record is [KONA-ROOT-DESIGN.md](../../KONA-ROOT-DESIGN.md).

[V] Local preparation, outside the three-patch upstream series:

```sh
# In an isolated worktree based on instantnoodlep-k3-combo at aa996bae0:
git revert 6ea434b7a3de31a8b57e6be4f8570554168a6b6e
# Then apply 0001 through 0003 in numerical order with git am.
```

[V] This drops the local vendor-compatible workaround before replacing it.
Existing root-match entries remain unchanged; only unmatched roots try the
SM8250 SMEM ID. Node matching scans every cpufreq-hw controller, including
an enabled node that follows a disabled one. The source files retain their
kernel licences; these kernel diffs are GPL-2.0, not MIT.

[I] Human review, device testing and DCO sign-off are required before any
upstream submission. The AI does not supply a human sign-off. Nothing in
this directory authorizes a phone operation or changes to DTBO/slot flags.
