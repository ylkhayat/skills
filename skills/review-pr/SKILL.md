---
name: review-pr
description: Review a GitHub PR with crit inline comments — iterate on the review through crit rounds, clean up on request, then post to GitHub on request. Use when asked to review a PR.
disable-model-invocation: true
argument-hint: "[pr-number]"
---

Review a GitHub PR by authoring findings as crit inline comments, then iterate on the **review itself**
(never the code) through crit rounds with the reviewer. The review file is a living document: internal
discussion happens in comment replies, and only a cleaned-up final set gets posted to GitHub.

You are the **reviewer** here. This skill never touches code.

**Repo- and team-specific values — repos, tooling commands, review bots, playbook skills — live in
`../review-exchange/config.md`.** Read it in Phase 0. It is the only file to edit to run these skills against a
different codebase; nothing below hardcodes a value that belongs there.

| Whose code | Skill |
|---|---|
| **Someone else's PR** | **this one** |
| Yours — local changes, or reviewers' threads on your own PRs | `/revise` |
| The vocabulary and reply shape both sides use | the **review-exchange** skill |

## Two rules that outrank every phase below

**Never write a file into the checkout.** No `.review/`, no scratch JSON, no repro script, no
worktree under the repo — the reviewer's `git status` must stay clean and nothing here is worth a
`.gitignore` entry. Everything transient goes under `$REVIEW_STATE/review-pr/`.

**`$REVIEW_STATE` is `${XDG_STATE_HOME:-~/.local/state}`**, or whatever `REVIEW_STATE_DIR` is set
to. The scripts resolve it themselves; it is written this way here so nothing assumes one agent
harness's config directory.


**1. Nothing reaches GitHub until the reviewer says so, in this session, for this round.**

Invoking this skill is a request for a *review*, never authorization to publish one. The review POST, an
inline comment, a thread reply, a `PUT` on the review body — each waits for an explicit go-ahead. It is
their GitHub account, their name on the thread, and the author gets a notification for each one.
Approval for round 2 says nothing about round 3. **The single exception** is a resolve in Phase 6 on a
fix you verified at the current head: that one is pre-authorized, because the resolve *is* the
acknowledgement and the alternative is a notification carrying nothing.

Read-only work needs no permission and should not wait for it. Fetch, diff, read files, run typecheck
and lint, check groundtruth in another repo, verify each claimed fix, build the payloads. Do all of it,
then stop at the network boundary and present what you have. When you catch yourself reasoning that a
phase "is the designed flow" — that is the failure mode this rule exists to stop. The gate is the
reviewer's sentence, not your reading of the skill.

**2. Always give the reviewer crit, even when you have nothing to say.**

Launch the daemon and hand over the URL on every round, including one where every thread already landed.
The reviewer reads the code themselves; the session is *for them*, not a delivery mechanism for your
findings. The one exception is the word **`autonomous`** in the reviewer's request.

## Phases

| # | Phase | Gate | Ends when |
|---|---|---|---|
| 0 | Context + relay the URL | none — read-only | the triage streams are dispatched |
| 1 | Arm the round | none | `crit.sh wait` is running |
| 1.5 | Ticket gate (skipped with no ticket) | none — but **wait** when it fires | the diff fits, or the reviewer answers the rescope call |
| 2 | Author | none | `crit.sh verify` says VERIFIED |
| 3 | Discuss (loops) | none | the reviewer asks for cleanup |
| 4 | Clean up | reviewer asks | the final set is printed for sign-off |
| 5 | Submit | reviewer asks | the review URL is reported |
| 6 | Later round | resolves pre-authorized; replies and the body `PUT` gated | the round is reported |

Never clean up, submit, reply, or edit a review body unprompted.

## One state file, one renderer

Every finding is a record in **`findings.json`**, and `scripts/render.py` is the only thing that turns a
record into text — the crit body, the GitHub comment, the ledger row, the review body. Write fields, not
markdown. A finding that exists in two hand-written copies is a ledger that will disagree with its
threads.

```json
{ "pr": 3266, "owner": "acme", "repo": "web", "round": 1,
  "ticket": "ENG-318", "verdict": "Follows", "aidr": "…", "takeaway": "…",
  "meta": { "files": 12, "rung": 4, "didnt_run": "migration rerun (no local DB)" },
  "findings": [
    { "id": "f1", "path": "apps/api/x.ts", "line": 357, "start_line": null,
      "severity": "HIGH", "ask": "blocking", "status": "open",
      "flagged_by": "@ylkhayat, round 1", "endorsed_by": ["cursor[bot]"],
      "claim": "…", "failure": "…", "fix": "…", "repro": "…",
      "why": { "mechanism": "…", "detail": "…", "takeaway": "…", "not_verified": "" } },
    { "id": "f2", "reply_to": "<crit comment id>", "claim": "Endorsed — …" }
  ] }
```

Keep it in the scratch dir Phase 0 printed (`$REVIEW_STATE/review-pr/pr-<n>/`) — never in the checkout.
`gh-review.sh submit` copies it, with the review id and thread
urls filled in, to `$REVIEW_STATE/review-pr/<owner>-<repo>-<n>.json`, which is what Phase 6 reads.

**Load the review-exchange skill and read `references/finding-shape.md` before authoring the first
finding.** `review-exchange` is the contract shared with `/revise` — the two badges, the verdict
badges the author answers with, the confidence ladder, the cite rules, the marker and who resolves.
`finding-shape.md` is how a finding becomes a record in `findings.json`. Neither this file nor that one
restates the contract: fix a rule about the vocabulary in `review-exchange` and both skills inherit it.

## Phase 0: context, and the URL

```bash
scripts/pr-context.sh [pr-number]
```

Resolves the PR (argument, then the current branch), fetches metadata, diff, comments and reviews in
parallel, computes the **merge-base range** — `crit --pr` folds in base-branch commits and surfaces
files that aren't part of the PR — creates the review worktree, clears stale crit daemons, starts
typecheck and lint in the background, **launches crit on the pinned port**, and prints the round number,
the panel verdict, the counts and the crit URL. `cd` into the worktree it names and work there for every
phase.

**Relay that URL before you do anything else.** It is live the moment the digest prints, and every minute
you spend on triage first is a minute the reviewer spends looking at nothing:

> Crit is open at http://localhost:PORT — you can start reading the diff now; my comments will appear as
> I add them. This URL stays the same for the whole review.

**Never check the PR head out in the main worktree** — that strands the reviewer on a detached HEAD. The
script handles this; don't do it by hand.

Then dispatch **streams A and B in one message** (`references/fan-out.md`) and read `diff.patch`
yourself while they run. Both are read-only and neither blocks the other:

- **Stream A — existing comments.** Human feedback first, bots second (the `review bots` row of `config.md`); group
  replies with their parents. For each one, **read the actual current file** at that location — the
  branch may have been force-pushed — and classify ADDRESSED / PARTIALLY ADDRESSED / NOT ADDRESSED,
  noting author justifications ("deferred to #NNNN in the stack").
- **Stream B — the ticket, and the stack.** Read the ticket if the digest found one. Absent is not a finding. With one in hand, settle on
  **one** verdict and carry it into the AI;DR: **Follows** (implements it and nothing else) ·
  **Supplements** (plus work it doesn't mention — name the extra in half a sentence) · **Partial**
  (name what's missing) · **Contradicts** (a finding in its own right) · **Unrelated** (usually a wrong
  reference). The verdict is about the ticket, not about quality: a **Follows** diff can be full of HIGH
  findings, and a **Contradicts** one can be better than the ticket it departs from — say so and let the
  reviewer decide which should change. **If the PR is part of a stack** (base isn't one of config's `trunk branches`, or
  comments reference stacked PRs), the same agent checks the adjacent PRs so you don't flag what is
  intentionally deferred there.
- **Read the typecheck and lint logs** the script left in the scratch dir (`$REVIEW_STATE/review-pr/pr-<n>/`). A red typecheck on a changed file
  is a free HIGH with a `repro` already attached, and everything the tools cover is off your list. Don't
  run the test suites; CI owns those.
- If `node_modules` is missing and you need types or implementations of dependencies, run config's `install` in the
  background rather than guessing.

## Phase 1: arm the round

**One session for the whole review, on a port pinned to the PR** — Phase 0 already started it. The port
comes from `crit.env` in that same scratch dir and is derived from the PR number, so it is the same on
every launch and after every restart; crit picks a random port by default and drops `--port` on
reconnect, which is what used to kill the reviewer's open tab.

`scripts/crit.sh launch` is idempotent and reports a live daemon rather than restarting it — run it only
if the digest said the launch failed, or the daemon died mid-review. Otherwise this phase is one call:

```bash
scripts/crit.sh wait          # run_in_background: true
```

`wait` blocks until the reviewer clicks **Finish Review** and returns that round. It is also what
*releases* their browser — see Phase 3. Restarts, re-anchoring and the `--session` trap are in
`../review-exchange/references/crit-mechanics.md`; read it before your first raw `crit` call.

## Phase 1.5: the ticket gate — only when a ticket exists

**A linked ticket says what the diff should contain, and that is worth more than any lens applied
afterwards.** Stream B has come back by now with the ticket, its verdict, and its size estimate. Spend
one step on this before dispatching a single shard, because every pass after it is priced per file:

1. From the ticket's acceptance criteria alone, name the files a minimal implementation would touch.
   Rough is fine — the question is five versus twenty-five, never four versus six.
2. Compare that to the digest's `size`. **If the diff is plainly over — a multiple, not a margin —
   the review's primary output is a rescope, not findings.**

When it fires, stop and hand the reviewer the aggregate call (`references/scope-lens.md`) before
reading further: the expansions, what each dragged in, and what the minimal version is. Then **wait**,
because the answer changes what is worth reviewing. A rescope agreed is a diff about to lose most of
its files, and correctness findings on those files are work nobody will read.

- **Defer the panel** (`design-lens.md`) rather than running it. Three models on a diff about to be cut
  by most of its surface is the single most expensive way to generate noise in this skill.
- **Shard only what a minimal version keeps.** Everything else gets the scope pass it already had and
  no correctness pass — no design lens, no rung-4 chase, no deletion lens. A defect in a file that is
  reverting is not a defect.
- **A `Supplements` verdict is the trigger's other half.** It is the one verdict that means *the diff
  exceeds the ticket*; treat it as a reason to run this gate, not as a word for the metadata line.
- **Absent, unsized, or a diff that fits: skip all of this** and carry on to Phase 2 normally. Most
  PRs are the size of their ticket, and this gate costs one comparison to find that out.

The reviewer overruling the gate ("review it as-is") is a complete answer — dispatch everything and
review the diff in front of you.

## Phase 2: read, author, verify

Read the changed **files**, not just the diff — **`references/fan-out.md` says who does that reading**.
Above three changed files it is streams C and D, dispatched in one message with A and B's results in
hand; at three or fewer it is you. Flag correctness, security, performance, consistency and design
issues into `findings.json` per `references/finding-shape.md`. For design, load
`references/design-lens.md` — it also owns the panel trigger the digest reported. For whether a hunk
belongs in this PR at all, load `references/scope-lens.md` alongside it and file what survives its
exclusion list as SCOPE. For whether it needs to exist at all — a guard with no threat, a helper with no
caller, a fallback for a shape nothing emits — load `references/deletion-lens.md`; it is the one that
catches what the other two wave through. Write the review-level
fields per `references/review-body.md`.

**You are the lead, not an aggregator.** Dedup across the streams, find the one load-bearing fact,
assign severity, and chase every HIGH to rung 4 yourself — an agent's claimed red-then-green is not
evidence until the command is in the record and you have seen it. Only the lead writes `findings.json`.

```bash
scripts/crit.sh author findings.json        # renders, one bulk call, then verifies
```

Verification is not optional and the count crit reports is not enough: `crit.sh` checks the per-file
endpoint the diff view actually fetches, the review-level comment, and that no entry landed a null
`focus_key` — a null-keyed comment is **invisible in the browser** while `crit status` still counts it.
A FAIL there is a daemon-resolution problem; fix that and re-author. A restart does not fix it, and you
never hand-edit `focus_key`.

Then tell the reviewer the comments are in (same URL), to leave replies in the browser, and to click
**Finish Review**. Wait for the `crit.sh wait` background task to complete — do not poll, do not proceed
early. If that task died, the click is still recorded: `scripts/crit.sh finished <count you last saw>`
reads the durable finish log.

## Phase 3: discussion rounds (loop)

**Re-arm before you work, not after.** A finish with open comments leaves the reviewer in a modal
reading "Waiting for your agent to finish...", and in a range session the only thing that clears it is
the next `crit.sh wait`. So the first thing you do on every round is:

```bash
scripts/crit.sh wait          # run_in_background: true — releases their browser AND arms the next round
```

Then read `review.json` and process every comment:

- **Replies to your findings.** Dismissals ("fine", "can be ignored", "per spec", "let's drop") mark the
  record for removal at cleanup — leave it in place for now. Questions mean **investigate**: read code,
  check installed package behaviour, survey conventions, then reply with concrete evidence. If the
  evidence materially changes a finding, edit the record so it stands alone, and say so in the reply.
  **Agreement adds a name to `endorsed_by`**; it is the only thing that does.
- **Other reviewers' threads.** Reply once, endorsed or not endorsed, per `finding-shape.md`.
- **The reviewer's own new comments.** These become records with `flagged_by` set to them — as their
  **GitHub login**, not the display name crit's `author` field carries (`gh api user --jq .login`; see
  the provenance rules in the **review-exchange** skill). These are drafts to the author. Reply with facts that strengthen,
  correct or contextualize them. Don't rubber-stamp; if a claim is wrong, show the counter-evidence.

Add the replies as `reply_to` records and re-run `scripts/crit.sh author findings.json`. Never pass
`--resolve`. Summarize what you did. Repeat until the reviewer asks for cleanup.

**A round you were not listening for is not a round you lost.** `scripts/crit.sh finished <n>` reports
how many finishes the global crit hook has recorded; if it is ahead of what you have processed, read
`review.json` and pick the round up from there.

## Phase 4: cleanup (only when the reviewer asks)

Cleanup is a **synthesis**, not a deletion — posting the pre-discussion version throws away the
conclusion the author needs.

1. **Delete** every record the reviewer dismissed, plus junk and meta.
2. **Fold each thread into its record.** The outcome goes **into the fields**: a corrected mechanism
   rewrites `why.mechanism`, a changed conclusion rewrites `why.takeaway`, a redirected fix rewrites
   `fix`. Where the reviewer gave direction ("my point still stands", "leave the rename to the author"),
   the record reflects it. No trailing "**Agreed in review.**" — a thread that ended somewhere different
   is a record whose fields say so.
3. **Assign the `ask` here, after the discussion.** A SCOPE record the reviewer did not dismiss
   keeps its `non-blocking` — there is nothing to downgrade it to, and nothing promotes it. A thread that opened `blocking` and closed on a
   design disagreement is a `question`; one the reviewer downgraded is `non-blocking`. Phase 6 closes
   threads against the ask, so it has to describe where the thread landed.
4. **Check the provenance.** Every survivor carries a `flagged_by` that is true after the discussion —
   a finding the reviewer reframed is theirs — and an `endorsed_by` holding only names that actually
   agreed on the thread. Never add one to make a finding look heavier.
5. **Rewrite the review-level fields**: `aidr` to where the review actually *landed*, `takeaway`
   deduplicated across the survivors, the counts follow from `status`. Strip internal bookkeeping.
6. Keep the `replies` in `review.json` — it is the durable record a later round resumes from. Only the
   GitHub payload is flattened.

Print the final set for sign-off — `scripts/gh-review.sh submit findings.json --dry-run` prints exactly
the bytes that will land. Wait for the explicit go-ahead.

## Phase 5: submit (only when the reviewer asks)

Read `references/review-body.md` for the event table and the two things that come from the reviewer —
their note and, on an approve, a GIF. Ask for **both in one message** before building the payload.

**Mark authorship: this is the only place `/ai-ethics` gets loaded.** The marker policy — crit
unmarked, GitHub marked, every unit, whatever a record's local `author` said — is in `review-exchange`.
Load `/ai-ethics` here, and the renderer prefixes its badge to the body and to every posted comment.

```bash
scripts/gh-review.sh submit findings.json
```

Three calls, because the ledger can't link to threads that don't exist yet: POST the review, read the
comments back and pair them to the records, `PUT` the body with the links in. **Skip `crit push`** — it
classifies everything `full-stack-only` and posts nothing. `gh-review.sh` refuses any event but
`APPROVE`/`COMMENT`, and on a failure it tells you to list the reviews before retrying rather than
double-posting.

**Re-anchor file-scope records first.** GitHub cannot inline a whole-file comment, and an out-of-diff
line **422s the entire review** — nothing lands partially. Give each one a `line`/`start_line` inside a
diff hunk, or fold it into the body; the renderer refuses to build a comment with no line.

Then: `crit stop`, remove the review worktree (`cd` out, then `git worktree remove <wt>`; `--force` only
if it is dirty and the reviewer confirms), delete the scratch dir (`$REVIEW_STATE/review-pr/pr-<n>/`), and report the review URL.
The review file under `~/.crit/reviews/<id>/` stays — it is the thread history a later round resumes
from.

## Phase 6: later rounds

Read `references/later-rounds.md`, and the **review-exchange** skill for the reply shape and the resolve
etiquette. In short: verify offline, **resolve what you verified without asking**, launch crit and relay
the URL, present the replies and the refreshed body, and wait for the go-ahead on those.
`gh-review.sh resolve|reply|refresh` are the three calls.

## Mechanics

Three shared files own what is not this skill's alone; fix it there, not here.

- **`references/scope-lens.md`** — what makes a hunk out of scope, the exclusion list, the transitive closure and the three-cluster cap. Shared with `/revise`.
- **`references/deletion-lens.md`** — the counterparty table, the grep that is the evidence, the never-simplify exclusions, and the earlier-round exception. Shared with `/revise`.
- **`references/fan-out.md`** — the stream table, the width thresholds, the return schema, and what the lead still has to do alone.
- **the **review-exchange** skill** — the badges, the ladder, the cite rules, the reply shape, who resolves, the marker. Shared with `/revise`, which answers the threads this skill opens.
- **`../review-exchange/references/crit-mechanics.md`** — the single-session precondition, the `focus_key` trap, the verification endpoints, restarts and ports, deleting a comment, why `crit push` is useless.
- **`../review-exchange/references/github-review-api.md`** — ids and anchors, the reviewThreads query, the replies endpoint, the resolve mutation, whose account this posts under.
