# The scope lens

`design-lens.md` asks whether the code is shaped right. This one asks whether it belongs in **this
PR** at all — a hook nobody calls, a drive-by rename, scaffolding for next month's ticket. All of it
reads clean, passes every other lens, and still makes the PR bigger than the change it carries.

**the **review-exchange** skill owns what a scope note *is*** — SCOPE in place of a severity, always
`non-blocking`, one thread per cluster, a `won't fix` that needs no rung. This file is only how you
find one and where you stop. Both skills load it; `/revise` runs the same lens on its own diff.

**It is a nudge, and nothing here promotes it.** Being right about scope is worth one notification
and no argument. If the author keeps it, the thread is over.

## The anchor

The PR's purpose is **the ticket** — Stream B has already read it and settled on a verdict. No
ticket? The PR title and body. A hunk that does not serve that purpose is a **candidate**, never yet
a finding.

## Four shapes

- **Hitchhiker** — an unrelated fix or feature riding along. The most common, and the easiest to move.
- **Drive-by** — a rename, reorder or reformat in a file you were in anyway, beyond what the change forced.
- **Scaffolding** — built for a need the ticket does not have. `design-lens.md` calls this Speculative Generality and says why it is bad; this lens says where it goes instead.
- **Support-only** — exists solely to serve one of the above. Never its own finding — see the closure.

## The exclusion list is what keeps this from being noise

Never a scope finding, however unrelated it looks:

- anything the main change needs to compile, typecheck, or pass lint
- its tests, its types, its migrations, its barrel exports
- a mechanical rename or signature update the change forces at its call sites
- formatter output on lines the change already touched
- anything config's `convention files` require
- a one-line drive-by in a file already open — correct, and not worth a notification
- anything the ticket names, however loosely
- anything a reviewer or the author already justified ("deferred to #NNNN", "needed by the base PR") — Streams A and B surface these before you author

A candidate that survives all of that still needs a **home**: "its own PR", "the follow-up ticket",
"revert it". "Feels unrelated" with nowhere to put it is an opinion, not a finding.

## Transitivity: the closure

Most out-of-scope work arrives as a chain, and filing every link is three notifications for one
decision. For each candidate ask: **if this hunk were reverted, what else stops making sense?**

1. Anything whose *only* reason to exist is an already-marked hunk is a **dependent**.
2. Repeat until nothing new is absorbed — test → helper → hook is two hops.
3. **The root is the highest hunk in the chain**, the one that takes the most with it. Filing the
   barrel-file export and missing the hook it exports is the failure this rule exists to prevent.
4. Dependents go on the root's `drops_with`, never in a record of their own.

A hunk with an in-diff caller that is itself in scope is **not** a dependent — it is load-bearing,
and the chain stops there. That single test is what separates a cluster from a cascade.

## The cap: three clusters, then stop

At most **three** scope clusters per review. Past that it is not a set of nudges — it is a
`Supplements` ticket verdict and **one sentence in the AI;DR** ("this is really two PRs, X and Y"),
with **zero threads**. Ten scope comments is a review nobody reads, and the author already knows.

## Check the total against the ticket, even when every candidate was excluded

**Zero surviving clusters is not the same as "the size is fine", and the exclusion list is very good at
producing the first while hiding the second.** Each hunk traces to something legitimate — a reviewer
asked for it, the change needed it to compile, an earlier round justified it — and the per-hunk test
dissolves them one at a time while the diff stays many times the size of its ticket. Six of eight
excluded because a reviewer asked is still an XS ticket in twenty-four files.

**Where this runs matters as much as whether it runs.** With a linked, sized ticket it belongs at
SKILL.md's **Phase 1.5**, before the fan-out, because its answer decides what is worth reading at all —
running it at cleanup means the panel and four shards have already been spent on files that are about
to revert. With no ticket, or no size on it, there is nothing to compare against until you have read
the diff, so it runs here at cleanup instead. Same question, same output, one place per review.

So after the exclusions — or at the gate, when there is a ticket — ask the aggregate question once:
**is this diff the size of its ticket?**
Compare the file and line counts in the digest against the ticket's own scope — its estimate when it
carries one (XS/S/M), otherwise the work its acceptance criteria actually name. When it is plainly
over, that is **one sentence in the AI;DR and no threads**, exactly as the cap prescribes — and it is
worth more to the author than the notes the exclusions ate.

The useful form is causal, not a number. Name the **expansions** and what each one dragged in — "moving
usage-limit denial into main pulled in the IPC extension, `MainApp` and the `CallSettings` rework; the
catalog pulled in four more" — and say what the minimal version would have been. A count is an
opinion; a list of expansions with their costs is something the author can act on.

**This outranks the individual findings when it fires.** Defects filed against code that a
minimal version never writes are defects about the wrong diff, so say which of your own findings
dissolve under it. That is the strongest evidence the aggregate call is right, and it stops the author
reworking code that should be deleted.
