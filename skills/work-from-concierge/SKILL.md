---
name: work-from-concierge
description: Ground rules for every agent run Concierge starts: the checkout is Concierge's, not the person's, branches are rebased, never merged, and no local typecheck, lint or test suites. Concierge adds it to every run.
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

Never run typecheck, lint, builds or test suites on this machine (`tsc`, `pnpm typecheck`, `pnpm lint`, `pnpm test`,
`nx affected`/`run-many`, `make test-unit`, `pytest` over folders, "rerun all checks"): the pull request's CI runs
them, and several agents running them at once starve the machine and stop Concierge. This holds even when a skill, a
repo's CLAUDE.md or an earlier message in this session says to run them. Read the PR's CI instead (`gh pr checks`, once: never `--watch` it or wait for it to finish; Concierge watches CI),
and say a red check as such. At most one targeted test, the one for the change (a single file or case), once.
