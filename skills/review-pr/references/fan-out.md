# The fan-out

One agent reading twelve files serially is the slowest part of a review that nobody is waiting on a
human for. This file is how Phase 0's triage and Phase 2's reading get split, and — more important than
the speed — how the file bytes stay **out of the main context**.

**The principle: the lead owns `findings.json` and never owns file contents.** Subagents read, the lead
synthesizes. A record is ~200 tokens; the file it came from is 8k. That is what keeps the cleanup pass,
the discussion rounds and Phase 6 cheap for the rest of the session.

## Width comes off the diff size, and nothing else

`pr-context.sh` prints `size` and `panel`. Read the width off that table and don't improvise:

| Diff | Streams | Agents |
|---|---|---|
| ≤3 files | **none — read it yourself** | 0 |
| 4–12 files | A, B, C×2, D | 5 |
| >12 files | A, B, C×4, D | 7 |
| `panel yes` | + E×3 | +3 |

**Below four files the fan-out loses.** Briefing an agent costs more than reading the file, and the lead
ends up re-reading anyway to dedup. Spawning three agents on a two-file PR is the failure mode this row
exists to prevent.

Dispatch every stream for a round **in one message** so they run concurrently. They are read-only and
independent; nothing here waits on anything else here.

**Count the width off the files a minimal implementation keeps, not off every changed file**, whenever
SKILL.md's Phase 1.5 gate has fired and the reviewer has agreed to a rescope. Files that are reverting
get the scope pass they already had and no C shard — a twenty-four-file diff that should be four is a
`≤3 files` review with a scope thread on top, not a seven-agent fan-out. This is where the gate pays
for itself; skip it and the table above prices a review of code nobody will merge.

## The streams

| | Stream | Model | Owns |
|---|---|---|---|
| **A** | Existing-comment triage | `haiku` | Every human and bot comment: read the **current file** at its location, classify ADDRESSED / PARTIALLY ADDRESSED / NOT ADDRESSED, capture author justifications ("deferred to #NNNN"). |
| **B** | Ticket + stack | `sonnet` | The ticket body, the verdict (Follows / Supplements / Partial / Contradicts / Unrelated) with the half-sentence that earns it, **the ticket's own size estimate** (XS/S/M/L, verbatim, or absent) for the aggregate check in `scope-lens.md`, and — when the base isn't main/develop — what the adjacent PRs in the stack already defer. |
| **C** | File shards | `sonnet` | An equal slice of the changed files. Correctness, security, performance, convention. Owns findings **in its slice**; reads outside it freely for context. |
| **D** | Seam pass | `sonnet` | Only what crosses a shard boundary: a changed signature vs. its call sites, a migration vs. its readers, a contract vs. its consumers, a renamed field vs. its serializers. **No single-file findings** — those belong to a C. |
| **E** | Panel | `opus`, `sonnet`, `fable` | Unchanged, and still gated on `panel yes` alone. See `design-lens.md`; the adversarial signal is model diversity, not personas. |

**D is what buys back what sharding costs.** Splitting by file is what makes C cheap and linear, and it
is also what hides the bug where the caller in shard 1 no longer matches the callee in shard 3. Without
D the fan-out trades recall for speed; with it, the trade is close to even. Never drop D to save an agent.

## Every agent gets paths, never contents

`pr-context.sh` already wrote `meta.json`, `diff.patch`, `comments.json`, `reviews.json` and the tooling
logs to the scratch dir. Pasting any of them into a prompt pays for the same bytes twice. Each brief
carries:

- the **worktree path** and the scratch dir, with the file it should read named
- its slice (C: the file list it owns; A: the comment ids; D: the seams you already suspect)
- `references/finding-shape.md` and, for C and D, `references/design-lens.md` and `references/deletion-lens.md`
- the repo's playbook skill by name, from the `playbook skills` row of `../review-exchange/config.md` — the agent
  loads it; you do not summarize it into the prompt. No row, no playbook: drop the line from the brief
- the standing bars: **no evidence line means it is not a finding**, a HIGH needs rung 4 or it is a
  MEDIUM, one fix not a menu

## They return records, never prose

Give every finding-producing stream (C, D, E) this schema and reject anything else. A paragraph summary
is the thing that puts the file back in your context by another route.

```json
{ "findings": [ { "path": "…", "line": 0, "start_line": null,
                  "severity": "HIGH|MEDIUM|LOW", "ask": "blocking|question|non-blocking",
                  "claim": "…", "failure": "…", "fix": "…", "repro": "…",
                  "rung": 2, "why": { "mechanism": "…", "detail": "…", "takeaway": "…", "not_verified": "…" } } ],
  "checked_and_clean": ["path …"], "could_not_check": ["…"],
  "off_ticket": [ { "path": "…", "line": 0, "what_it_does": "…", "used_by_in_diff": ["path:line"] } ],
  "dead_counterparty": [ { "path": "…", "line": 0, "construct": "…", "counterparty": "…",
                           "searched": "the grep you ran", "found_in_slice": ["path:line"] } ] }
```

- **`rung` is per finding**, and an agent that did not run anything says so rather than rounding up.
- **`off_ticket` is candidates, never findings.** A shard has not read the ticket and cannot know
  what serves it, so it reports what a hunk does and who calls it and stops there. `used_by_in_diff`
  is the edge — without it the lead cannot compute the closure from a slice, and the cluster becomes
  N comments.
- **`dead_counterparty` is candidates too, and for the same reason** (`deletion-lens.md`). A shard can
  name what a guard defends against and grep its own slice, but the producer or caller may live in
  another shard — so it reports the construct, the counterparty it looked for, the search it ran, and
  what it found, then stops. A shard that deletes on its own evidence is a shard that deletes the one
  caller the next shard owns.
- **`checked_and_clean` is load-bearing.** Without it you cannot tell a shard that found nothing from a
  shard that read nothing, and the second one is a hole in the review you would never see.
- A and B return their own shapes — a classification per comment, a verdict plus the deferred list.

## Agents never write anything

Read-only, all of them. No `findings.json`, no crit call, no edit in the worktree, no scratch file, no
`git` mutation. Findings come back through the return value and the lead writes the state file. Two
agents writing one `findings.json` is a lost finding, and an agent touching crit is a comment nobody can
attribute.

## The lead's part does not parallelize

You are the lead reviewer, and this is the half that stays serial because it needs the whole picture:

1. **Dedup across streams.** Two shards and a panel model will word one issue three ways. Three comments
   circling one edit reads as three problems.
2. **Two streams landing on the same thing independently is the strongest signal available** — that one
   goes in at its own severity. A lone finding needs rung 4 to be a HIGH.
3. **Find the one load-bearing fact** (`design-lens.md`). No shard can — each sees a slice.
4. **Assign severity, write the AI;DR and the takeaway, build `findings.json`.**
5. **Say what you threw out**, in the conversation, when you hand over the results. A dismissed pile the
   reviewer cannot see is one they cannot overrule.
6. **Collapse the `off_ticket` candidates into clusters** per `scope-lens.md`: apply the exclusion
   list, walk the closure, pick the root, cap at three. Run that file's **aggregate check** here only
   if Phase 1.5 did not already — a sized ticket moves it before the fan-out, and the point of it is to
   fire *before* the reading is paid for. Either way it runs *even when the exclusions left you
   nothing*, which is exactly when it is easiest to skip and most likely to fire. This is the lead's
   precisely because every step of it needs the ticket and the whole diff at once.
7. **Resolve the `dead_counterparty` candidates across the whole diff** per `deletion-lens.md`: union
   every shard's `found_in_slice` before calling anything dead, run the repo-wide grep yourself, and
   check the counterparty outside the repo when it is a wire field or a dependency. A shard's empty
   slice is not an empty repo.
8. **Chase the HIGHs to rung 4 yourself**, or dispatch one agent per HIGH to build the repro. An agent's
   claimed red-then-green is not evidence until the command is in the record and you have seen it.

## Later rounds

Phase 6 verification is the same shape, one degree simpler: **one `haiku` agent per claimed fix**, at
four or more, each returning `{thread_id, landed: bool, evidence, repro_result}` after reading the
current file at that line and re-running the finding's `repro`. Below four, do it yourself. The resolve
is yours either way — an agent's word is not the verification the pre-authorization rests on.
