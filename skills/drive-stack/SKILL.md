---
name: drive-stack
description: Drive a whole stack of pull requests to a consistent, finished state in one run - one agent for the whole stack, working bottom-up, resolving every cross-PR conflict and the person's answers, restacking and re-checking until nothing is left. Use when asked to resolve, answer or finish a stack (Concierge's "Resolve the stack").
---

# Drive a stack

You are the one agent for the whole stack. The PRs' own agents are not running; you do their parts. Your job ends
when the stack is consistent and its work is done, or when one decision only the person can make is left.

## Inputs (in the prompt)
- The chain, bottom first: number, branch, base, whether it is the person's PR.
- The direction the stack follows. It wins over anything a single PR's agent said.
- What waits: the person's answers per PR, open steps, the agreement check's issues, the person's steer.

## Method
1. **Read once, plan once.** `git fetch`, then read each PR's diff against its base (`git diff base...branch --stat`
   first, then only the files that matter). Write a short plan: per PR, bottom first, what changes. Settle every
   cross-PR question in the plan *before* editing anything, so no PR is changed twice in opposite directions.
2. **Bottom-up, one PR at a time.** For each PR in order:
   - Work in a worktree of its own: `git worktree add --detach <tmp> origin/<branch>` (never touch the person's
     checkout or a PR agent's worktree). Make its changes, run the checks that cover them (the project's own
     test/lint for the touched files only).
   - Commit (conventional message), then restack the PRs above onto it (`commit-with-stack` skill; `gh stack` when
     the repo uses it, else `git rebase --onto`). Resolve rebase conflicts by keeping both intents when they don't
     contradict; when they do, the lower PR and the direction win.
   - Re-read the PR above against the new base before you change it: what you just did may already settle its step.
3. **Check after each PR, not at the end only.** After each PR, re-run the agreement check yourself (`check-stack`
   skill's questions, against the real branches): one question decided two ways, a rename not followed, the same fix
   twice, work removed above that was added below.
4. **Push** only when the prompt says to push. Then push each changed branch bottom first with
   `--force-with-lease=<branch>:<sha you started from>`. Never push a PR that isn't the person's.

## Rules
- **Tolerate small deviation.** Different wording, an extra helper, a slightly different structure: fine if it doesn't
  contradict the direction or another PR. Don't "fix" style differences across PRs.
- **No churn.** Never add something in one PR that a PR above removes, or change then revert. If a lower PR has work
  the stack later drops, remove it at the lowest PR instead.
- **One PR's work stays in that PR.** Move a change down the stack when two PRs need it; never duplicate it.
- **Decide what you can.** Ask the person only for a product decision the direction doesn't settle; take the
  recommended option for everything else and say so.
- **Someone else's PR:** never change it; draft a comment for its author in your report instead.
- **Cheap reading.** Read stats and the relevant hunks, not whole files or whole logs. Don't re-run a full test suite
  per PR: the touched files' tests, once per PR.

## Finish
End with a short report: per PR one line (what changed, the new head sha, pushed or not), anything you decided for the
person, and drafted comments if any. Then exactly one of these lines on its own:
- `STACK done` - consistent, nothing left for the person
- `STACK needs you: <one question, with the options and your pick>`
