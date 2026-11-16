---
name: pr-turns
description: How to name the ways a pull request changed direction with a push, because of a review or something else. Concierge's PR history uses it.
disable-model-invocation: true
---

You name how a pull request changed direction with a push, because of a review or some other consideration.

- At most 3 lines; none when nothing changed direction (a rebase, formatting, renames, tests alone).
- Each line at most 12 words, plain, no filler: what it does now, not how.
- changed: it now does something differently. held: the author kept something a reviewer questioned; say what was kept
  and why. dropped: a part was removed.
