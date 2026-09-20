# Fan-out: several PRs at once

Reached from `SKILL.md` when more than one PR is in play. No crit, no human gate per PR — one agent per
PR, each in its own worktree. `--autonomous` is redundant here and silently ignored.

Everything in `SKILL.md` still binds: the **never rewrite published history** rule (every head here is
published, so every fix is a new commit), **nothing leaves the session until you are told** (agents
commit and draft; the parent publishes at Phase 6 on the human's word), the five classes, the finding and
fix bars, the confidence ladder, and the reply template. This file is only the orchestration.

The gate matters more here, not less: a fan-out being unattended is about the *agents* not needing a
human, never about the *push* not needing one. Eight branches pushed and answered on a guess is the worst
version of the mistake.

**Threads only.** An agent fixes what a human asked for, so every diff traces to a thread id. A fresh
finding it spots goes in the report, never into a commit — nobody asked for it, and eight branches moving
on unrequested work in one unattended pass is the failure mode this rule exists to prevent.

## Dispatch

The picker already scouted the threads, so **pass the work-list through `args`** rather than having eight
agents re-query the same PRs. One `Workflow` call:

```js
export const meta = {
  name: 'revise-fleet',
  description: 'Close out unresolved review threads across several of my PRs',
  phases: [{ title: 'Address', detail: 'one agent per PR: assess, fix, commit, draft reply' }],
}

const REPORT = {
  type: 'object',
  properties: {
    pr: { type: 'number' },
    repo: { type: 'string' },
    sha: { type: ['string', 'null'] },
    fixed: { type: 'array', items: { type: 'string' } },
    declined: { type: 'array', items: { type: 'string' } },
    blocked: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
  required: ['pr', 'repo', 'fixed', 'declined', 'blocked'],
}

const results = await pipeline(
  args.prs,
  (pr) => agent(instructionsFor(pr), {
    label: `pr-${pr.number}`,
    phase: 'Address',
    isolation: 'worktree',
    schema: REPORT,
  }),
)
return results.filter(Boolean)
```

`instructionsFor` is yours to write inline, and an agent has none of this session's context, so its
prompt carries all of it: the PR number and repo, its head branch, its unresolved threads **with root
comment ids**, the classes and the bars, the repo's verify commands, the `SHARED_CONVENTIONS` **path** (agents read it; it is never pasted into a brief), the commit and
push rule, and the reply template verbatim.

Respect the session's workflow-size guideline. Over it, chunk the list and run the workflow more than once
rather than shrinking what each agent does.

If `Workflow` is unavailable, fall back to `Agent` with `isolation: "worktree"`, one per PR, all in a
single message. Serialize in the main loop only if neither is available.

## What each agent does

1. **Reset to the remote.** Check out the head branch and reset to `origin/<branch>` — these get
   force-pushed under you, and a stale local copy silently rebuilds the wrong thing.
2. **Assess** each thread against the **current file on disk**, not the hunk quoted in the comment. Sort
   into the five classes.
3. **Fix** the minimal thing the thread asks for — a reviewer asking for a guard gets a guard, not the
   guard plus the refactor next to it. Where the thread names a behaviour, prove it red-then-green and
   quote that command in the reply. No code comments, docstrings, or documentation unless the thread
   explicitly asks for one; then write exactly that one.
4. **Verify.** Typecheck, lint, and the thread's own ask. Read `AGENTS.md` / `CLAUDE.md` for what the
   project expects and whether suites run locally. Distinguish breakage you caused from breakage already
   on the branch — stash and re-run to be sure — and report pre-existing breakage instead of quietly
   fixing it.
5. **Format, then commit once — and stop.** The repo's fix task over the tree, restore what it touched
   outside your diff, one commit for the PR. **Do not push.** The parent pushes, later, when told to.
6. **Draft** one reply per thread, to a file under `$REVIEW_STATE/revise/<pr>/` (`reply-<pr>-<thread>.json`, a
   `{"body": "..."}` object ready to `--input`), and return the paths. **Post nothing.**
7. **Report** in the `REPORT` shape, and clean up the worktree.

## Check the diffs, not the reports

An agent reports what it intended, which is not always what it did. Nothing is live yet, which is the
point — this is the pass where a bad edit is still cheap. Verify from the artifacts, not the reports:

- `git show <branch>` for each returned sha — the edit is the one the thread asked for, in the file it
  named, with nothing else riding along. A repro an agent claims went green gets re-run here.
- Read each drafted reply file against that diff — a `fixed` verdict whose diff doesn't show the fix is a
  **failed** item. Drop the draft, leave the thread alone, and say so in the report.
- Only what survives this pass is eligible for Phase 6. Publishing a draft you could not confirm is the
  same error as pushing one.

## Report back

Per PR: threads fixed, threads declined, threads waiting on you, the local sha and the drafted reply
paths — all held until you say to publish. Then the body
obligations, listed separately from the threads with their own outcomes, deferred ones included and what
would trigger them. Then anything the agents found that nobody asked about — pre-existing breakage, a fix
that will collide on the next restack, a finding worth its own ticket. If a PR is blocked, name it and the
thread; never quietly skip one.
