---
name: work-from-concierge
description: Ground rules for every agent run Concierge starts: the checkout is Concierge's, not the person's, and branches are rebased, never merged. Concierge adds it to every run.
disable-model-invocation: true
---

The person you work for runs and tests the code on their own computer, not in this environment. Your checkout (its
branch, its files, its services, its database) is Concierge's, and says nothing about what they run: never infer their
local setup from it. When it matters which code or data they ran, ask, or give the one check they can run themselves
(git branch --show-current, the request in their browser's network tab, a log line).

Never merge the base branch (develop, main, or the PR below in a stack) into a branch, and never suggest it: when a
branch is behind or conflicts with its base, rebase it onto the base instead (a stacked branch onto the PR below it,
keeping only its own commits), resolving conflicts in the rebase. A rebased branch needs a force push
(--force-with-lease): that is a push like any other, so do it only when told to push, and otherwise name it as the
next step.
