---
name: review-exchange
description: The shared vocabulary and reply shape for a code review thread — the two badges a finding carries, the provenance badges saying who flagged and who endorsed it, the verdict badge an answer carries, which answers a given ask accepts, the confidence ladder, the cite rules, and who resolves. Loaded by /review-pr (the reviewer's side) and /revise (the author's side) so one edit changes both. Load it before authoring a finding or answering one.
---

A review thread has two sides. `/review-pr` **asks** — it files findings on someone else's PR and never
touches code. `/revise` **answers** — it fixes its own code and replies. This file is the handshake:
the badges, the provenance, the shapes, and the etiquette both sides have to agree on for a thread to make sense.

**Neither skill restates what is here.** A rule about the badges, the ladder, the cites, the marker or
who resolves belongs in this file, and both skills inherit the edit. A rule about *how* to find a
finding, or *how* to land a fix, belongs in the skill that does it.

## The ask: two badges, always both

Severity is **consequence**. The ask is **what the other side has to do**, and it does not fall out of
severity — a LOW can be a `question`, and a HIGH can be `non-blocking` when the fix is already someone
else's ticket.

| Severity | Badge markdown | Means |
|---|---|---|
| HIGH | `![HIGH](https://img.shields.io/badge/HIGH-b91c1c?style=flat-square)` | Breaks something for a user. |
| MEDIUM | `![MEDIUM](https://img.shields.io/badge/MEDIUM-d97706?style=flat-square)` | A real defect, with a bound on the damage. |
| LOW | `![LOW](https://img.shields.io/badge/LOW-0969da?style=flat-square)` | Correctness or clarity debt, naming, wording — no behaviour at stake. |
| SCOPE | `![scope](https://img.shields.io/badge/scope-0f766e?style=flat-square)` | Not a defect. The change is fine and does not belong in this PR. |
| DEAD | `![dead](https://img.shields.io/badge/dead-86198f?style=flat-square)` | Not a defect. The code has no counterparty — no caller, no producer, no threat — and deletes cleanly. |
| NORM | `![norm](https://img.shields.io/badge/norm-4f46e5?style=flat-square)` | Not a defect. The code works and differs from a written convention: the house's, its libraries', or its language's. |

| Ask | Badge markdown | Means |
|---|---|---|
| blocking | `![blocking](https://img.shields.io/badge/blocking-1f2328?style=flat-square)` | Change the code before merge. |
| question | `![question](https://img.shields.io/badge/question-8250df?style=flat-square)` | A real fork. An answer is wanted, not an edit. |
| non-blocking | `![non--blocking](https://img.shields.io/badge/non--blocking-6e7781?style=flat-square)` | Take it or leave it, or pure context. No follow-up. |

## Provenance: who raised it, who agreed

A thread carries two more badges, on the same line, after severity and ask. They answer the question an
author cannot get from the text — **whose finding is this, and who else already looked at it.**

| | Badge markdown | Means |
|---|---|---|
| flagged | `![flagged Claude Code](https://img.shields.io/badge/flagged-Claude%20Code-D97757?style=flat-square&logo=anthropic&logoColor=white)` | Claude found it. The default; renders on every finding with no `flagged_by`. |
| flagged | `![flagged @ylkhayat](https://img.shields.io/badge/flagged-@ylkhayat-6e7781?style=flat-square)` | A human raised it and Claude wrote it up. |
| endorsed | `![endorsed @ylkhayat, cursorbot](https://img.shields.io/badge/endorsed-@ylkhayat%2C%20cursor%5Bbot%5D-6e7781?style=flat-square)` | Who agreed after reading it. Omitted when nobody has. |

- **`flagged` is exactly one value and always renders.** Orange with the Anthropic mark means Claude;
  slate means a person or a bot. A finding built on an earlier round or someone else's comment says so in
  that one value — `@ylkhayat, round 1`, `cursor[bot]` — rather than growing a third badge.
- **A human or bot value is that account's login, never a display name.** `@ylkhayat`, not `@Youssef`;
  `cursor[bot]`, not `Cursor`. A display name is not an address — it does not link, and one person's
  first name is another account's handle, so a wrong guess credits or blames a different human. Take it
  from the data you already have (`gh api user --jq .login`, the PR's `author.login`, the comment's
  `author.login`) rather than from how someone signs their crit comments, which is a display name.
- **`endorsed` is a list in one message**; shields has no multi-value badge, so the renderer joins with
  commas and caps at two names plus `+N`. Order is the order they agreed in.
- **Nobody endorses their own finding.** `Claude Code` appears under `endorsed` only when a human flagged
  it and Claude backed it, and a name never appears in both badges on the same thread.
- **Only earned endorsements.** A name goes there because that person said so on the thread — in crit, in
  a PR comment, in review. Never inferred from silence, and never from "they'd probably agree".
- These badges are **provenance, not weight**: three endorsers do not promote a LOW, and a `question`
  flagged by a human is still a `question`. The ask is the contract; this is the audit trail.
- They ride on the **thread**, never in the review body's ledger — the ledger is a map, and provenance is
  something you want where the conversation is.

`--` is how shields.io escapes a literal hyphen, so `non--blocking` renders `non-blocking`. Spaces are
`%20`; an apostrophe passes through as-is.

Severity is about consequence, not confidence — when unsure, file it as a `question` rather than picking
a severity you can't defend. **No evidence means you do not have a finding**; a `question` is the honest
form of a hunch.

## Scope: the nudge that cannot be escalated

A hunk can be correct, conventional, well-tested and still make the PR bigger than the change it
carries — a hook nobody calls, a drive-by rename, scaffolding for next month's ticket. That is a
**scope note**, and it is the lightest thing either side can file.

- **SCOPE occupies the severity slot; it never carries one.** There is no HIGH scope finding, because
  a scope note is not a defect and has nothing to inflate. A hunk that is out of scope *and* broken
  is two findings, or — usually — just the defect.
- **The ask is always `non-blocking`.** Not `blocking`, because it is the author's PR; not
  `question`, because a question demands an answer and a nudge does not. `render.py` dies on anything
  else, so this is mechanical rather than aspirational.
- **`won't fix` on a scope note needs no rung.** "I want it in this PR" is the whole answer. This is
  the single exemption from the rung-3 bar for declining, and it exists so the nudge stays cheap to
  refuse — nobody owes evidence for keeping their own code.
- **One thread per cluster, never per hunk.** Everything that exists only to serve the root is named
  on the root's `Drops with it:` line and gets no thread of its own. Three comments for a hook, its
  barrel export and its test is one finding wearing three notifications.
- **A scope note names a home** — "its own PR", "the follow-up ticket", "revert it" — or it is not a
  finding. "Feels unrelated" with nowhere to put it is an opinion.
- **It never moves the review event.** `non-blocking` already means an `APPROVE` survives it, and a
  review that withholds approval over scope is a review that blocked on taste.

How to *find* one, the exclusion list that keeps it from being noise, and how the transitive closure
is computed are in `../review-pr/references/scope-lens.md` — one file, both sides.

## Dead: the deletion that carries its own search

SCOPE says *not here*. DEAD says *not anywhere* — a guard with no threat, an exported helper with no
caller, a fallback arm for a field nothing emits, a compat shim for a version nobody runs. It reads as
diligence from every other angle, which is why it survives review until someone names the counterparty
and goes looking for it.

- **DEAD occupies the severity slot and never carries one.** Code with nothing on the other end of it
  has no consequence to grade. A dead guard that *also* breaks something — it suppresses a path,
  swallows an error, deletes a route — is a defect at its own severity whose `fix` happens to be a
  deletion, and it is filed that way, not as DEAD.
- **The ask is always `non-blocking`**, same as SCOPE and for the same reason: it is the author's PR,
  and removing correct-but-unused code is never worth withholding a merge over. `render.py` refuses
  anything else.
- **The search is the evidence, and it goes in `repro`.** `render.py` refuses a DEAD finding without
  one. "Looks unused" is rung 1; `grep -rn <name> src/ | grep -v '\.test\.'` returning only the
  definition is rung 2 and settles it. A claim about a *wire* field needs the line that writes the
  response, not the type that permits it — an allowlist permitting a field is not evidence it ships.
- **Count test files out when you look for callers.** Coverage keeps dead code looking alive; a
  predicate with nine assertions and no caller is the single most common shape here.
- **`won't fix` needs no rung**, exactly as for SCOPE. "I want it there" is the whole answer.
- **One record per construct.** The helper, its test and its barrel export are one finding — the same
  closure rule scope notes use.

The counterparty table, the never-simplify exclusions, and the sharp case — a construct an earlier
round asked for, on a premise that turned out wrong, which is a `question` on *that thread* and never a
unilateral deletion — are in `../review-pr/references/deletion-lens.md`, one file, both
sides.

## Norm: the drift that carries its source

SCOPE says *not here*, DEAD says *not anywhere*. NORM says *not how it is usually done* — an effect that
derives state, updates in a loop where the driver has a bulk call, an error swallowed where the
framework's docs say rethrow. Each one is fine alone; together they are how a codebase drifts from what a
new hire, a library upgrade or the docs expect.

- **Three tiers, and the nearest wins.** House (the repo's ADRs, `CLAUDE.md`, lint config) over ecosystem
  (the official docs of the library, at the version the repo pins) over language (its style guide, RFCs).
  Where the house chose differently on purpose, the code following the house is *aligned*, not drift.
- **NORM occupies the severity slot and never carries one.** A drift that breaks something, leaks data
  or opens a hole is a defect at its own severity whose fix happens to be the norm — filed that way,
  never as NORM. NORM is what is left when nothing is broken.
- **The ask is always `non-blocking`.** It informs the author; it never withholds an approval.
  `render.py` refuses anything else.
- **The source is the evidence.** `norm` is the rule in one line; `source` is an https link to the
  primary document that states it — the library's docs, the ADR, the style guide. Not a blog, not a
  Stack Overflow answer, not "common practice". `render.py` refuses a NORM without both.
- **`won't fix` needs no rung, and it has a name: deliberate.** "We do it this way on purpose" is the
  whole answer. A deliberate exception the author keeps is a house norm in waiting: say where it should
  be written down (an ADR) if it is not already.
- **One thread per rule per PR**, naming every place it drifts, not one per occurrence.

How to find them, the version check, and the exclusions that keep this from becoming taste are in
`../review-pr/references/norms-lens.md`.

## The answer: one verdict badge

| Verdict | Badge markdown | Means |
|---|---|---|
| fixed | `![fixed](https://img.shields.io/badge/fixed-1a7f37?style=flat-square)` | The code changed in this round. |
| already fixed | `![already fixed](https://img.shields.io/badge/already%20fixed-1a7f37?style=flat-square)` | It was already handled; here is where. |
| won't fix | `![won't fix](https://img.shields.io/badge/won't%20fix-8250df?style=flat-square)` | A decision, with the reason and where the trade is written down. |
| needs your call | `![needs your call](https://img.shields.io/badge/needs%20your%20call-b91c1c?style=flat-square)` | The decision is handed back. Only when you have *not* made it. |

**Which verdicts an ask accepts** — this table is the contract, and it is why both badges are mandatory:

| The ask | Legitimate answers | Not an answer |
|---|---|---|
| `blocking` | `fixed`, `already fixed`, `won't fix` | silence, or `needs your call` on a bug you can fix |
| `question` | any of the four — an answer in prose is the deliverable, an edit is optional | a code change with no reply saying which fork you took |
| `non-blocking` | any, including no reply at all | an argument; it was take-it-or-leave-it |

A `won't fix` needs **rung 3 or better**. Declining a reviewer from rung 1 is how a real bug gets talked
out of a PR. Deferred work is a sentence and an offer to file it, never a paragraph relitigating the ask.

## Say how sure you are, on the ladder

Every claim — a finding or an answer — sits on one of five rungs:

**(1)** you said so, worthless on its own · **(2)** you pointed at the line, a real `path:line` or the
library's own source · **(3)** you walked the failure step by step and showed the bad case can't be
dodged · **(4)** you ran it — a script or test that calls the real code and fails loud if you're wrong ·
**(5)** you reproduced it in the running app.

Get each claim as far down as is cheap, and **say where it stopped**.

- **A HIGH lands on rung 4.** Run one thing that fails on exactly this symptom and would pass without the
  bug: a scratch vitest, a `node -e` against the installed dependency, a `curl` at a dev server. Quote it
  with what it printed. Reading the file proves the code *says* X; a red command proves X *breaks* — and
  it is the same command that proves the fix. **A HIGH stuck at rung 2 is a MEDIUM or a `question`.**
- **A `fixed` on a HIGH re-runs that same command and expects green.** Red-then-green on one command is
  the whole proof, and it is what lets the reviewer resolve the thread without re-deriving anything.
- **Say what you could not check.** A confident claim you did not verify is worse than a hedged one you
  did. Delete scratch repro files before publishing.

## Every reference autolinks, or it is not a reference

Backticks suppress GitHub's autolinker, so a SHA or a PR number inside a code span renders as dead text —
the most common way a review's cites stop being clickable.

- Commits and PRs go **bare**: 95b213d06, #3146. Cross-repo needs the full prefix: acme/mobile@e7a0bce, acme/web#3146.
- A `path:line` has no autolink at all, so the load-bearing cite is a markdown link to a blob permalink pinned to **the SHA you actually read**, `#L165` or `#L165-L177` for a range:
  `[user.controller.ts:165](https://github.com/<owner>/<repo>/blob/<sha>/apps/api/controllers/user.controller.ts#L165)`
  A branch-name URL is not a permalink and rots on the next push.
- **One linked anchor per comment.** Incidental cites stay plain — one is navigation, six is noise.
- When the claim rests on something outside the diff — another repo, a library's behaviour, a live config — name it at a version: `mongoose 7.8.11`, acme/mobile@e7a0bce · `App/Info.plist`, a Slack or Linear link.
- Check a form you are unsure of against `gh api -X POST /markdown` with `mode: gfm` rather than guessing.

## The reply shape, both directions

A reply is **above the fold, a toggle, and an evidence line**. Nothing else — no headings, no bullet
lists, no restating the other side's comment back at them, no crediting them for raising it. Someone
scanning eight collapsed threads sees the badge and the first line, and that has to be enough.

```markdown
<the GitHub marker from /ai-ethics, verbatim>

![fixed](…) **AI;DR** — `?? null` at `commitSession.ts:162`, so a field cleared at the IdP is now written rather than dropped by mongoose. Pinned red-then-green by the test named below.

<details><summary>Evidence</summary>

Repro: `pnpm vitest run commitSession.test.ts -t "clears picture"` → red before, green after.
</details>

37ad3509 · `apps/api/session/commitSession.ts:162`
```

- **The AI;DR is the reply.** Two or three sentences, one paragraph: what you did or why you didn't, the
  one fact that settles it, and what proves it. **A fourth means you are arguing rather than answering** —
  cut it, or move it into the toggle.
- **The toggle holds what the other side would otherwise re-run themselves** — the red-then-green repro,
  a before/after table when the claim genuinely is a matrix, a mutation result. Leave a blank line after
  `<summary>` or the markdown inside won't render. **Omit it** when the first line already carries the
  proof; most replies have no toggle at all.
- **The last line is evidence and holds nothing else.** The commit short sha for anything that changed, a
  `path:line` when the reader needs to look at something specific, a link when the answer came from
  outside the diff.
- **One reply per thread, threaded onto the root comment.** A fresh review POST opens a parallel thread on
  the same line and splits the conversation. Endpoints and the REST/GraphQL id bridge:
  `references/github-review-api.md`.

## Who resolves

**The reviewer resolves; the author never does.** A resolve is a public claim that a thread is closed, so
it belongs to the side that raised it.

- `/revise` leaves **every** thread unresolved, however certain the fix. That is how the reviewer
  sees the reply.
- `/review-pr` resolves on a later round, once it has read the current file at that line and re-run any
  repro green. A verified fix is resolved **without** a reply: "thanks, fixed!" restates what the diff
  already shows and costs a notification to say nothing.
- A thread the other side disagreed on is theirs to close. Neither side resolves out from under an open
  disagreement.

## The marker

**Nothing inside crit carries an attribution marker** — the crit review file is a private working
document between Claude and one human, and `--author 'Claude Code'` already says who wrote it.

**Everything posted to GitHub does.** Load `/ai-ethics` at the point of publishing and copy its line
verbatim; that skill owns the marker and neither review skill restates it. One marker per published unit,
at the top, whatever a record's local `author` field said — by the time a thread is posted, Claude has
drafted or reshaped it, and splitting marked from unmarked hides AI authorship under a human account.
