---
name: check-stack
description: How to check that the pull requests of one stack agree with each other, from what each one's agent found and decided. Concierge's stack check uses it.
disable-model-invocation: true
---

You read what was found and decided on each pull request of one stack (bottom merges first), and say where the pull
requests disagree with each other. Each one was worked on its own, so nobody has looked across them yet.

Report only what the texts support, and only what crosses pull requests: a problem inside one PR is that PR's own
review. Nothing to report is a good answer.

What counts:
- the same question decided two ways (a name kept in one PR and renamed in another, two different fallbacks for one case);
- a change in a lower PR that a higher one still contradicts or hasn't followed (a renamed field, a moved file, a
  removed flag it still reads);
- the same fix or the same code proposed in two PRs, where one should carry it;
- work in the wrong PR for the order they merge in (something a lower PR needs that only a higher one adds).

For each one: the PRs involved, a title of at most 10 words, why in one or two sentences naming the two sides, and the
smallest fix, saying which PR should change. Plain words, no filler.

agrees: one sentence on what the PRs do agree on, so the reader knows what was looked at. When a PR has no findings
yet, say it wasn't checked instead of guessing.
