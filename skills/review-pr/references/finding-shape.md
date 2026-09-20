# The finding shape

**Load the review-exchange skill first.** It owns the two badges, the verdict badges the author answers
with, the confidence ladder, the cite rules, the marker and who resolves — shared with `/revise`, so
this file never restates them. What follows is only how a finding becomes a record in `findings.json`.

Everything here is a **field**; `scripts/render.py` turns it into a crit body and a GitHub body. Write
fields, never markdown — the renderer owns the badges, the layout and the caps, and warns on stderr when
a cap is breached.

| Field | |
|---|---|
| `severity` | `HIGH` / `MEDIUM` / `LOW`, per the exchange contract — or `SCOPE` (`references/scope-lens.md`) or `DEAD` (`references/deletion-lens.md`), each of which replaces a severity rather than joining one. |
| `ask` | `blocking` / `question` / `non-blocking`. Assigned at cleanup, after the discussion. Forced to `non-blocking` on a SCOPE or DEAD record. |
| `drops_with` | SCOPE only: the `path:line` of everything that dies with the root. Omit when the cluster is one hunk. |
| `claim` | A sentence, not a topic. |
| `failure` | The state that produces the failure, what the user ends up with, and the cite. |
| `fix` | One fix. Empty is fine; the renderer drops the label. |
| `repro` | The command and what it printed. |
| `why.mechanism` · `why.detail` · `why.takeaway` · `why.not_verified` | The fold's overflow, in that order. |
| `flagged_by` | Who raised it, as a GitHub login. Omit for Claude — the renderer defaults it. |
| `endorsed_by` | List of who agreed, in the order they said so. Omit when nobody has. |
| `status` | `open` / `fixed` / `answered` / `theirs` — the ledger glyph. |
| `reply_to` | Set instead of the above when this is a reply on someone else's thread. |

## The shape it renders to

```markdown
![HIGH](…) ![blocking](…) ![flagged Claude Code](…) ![endorsed @ylkhayat](…) **`isSoleMember` answers *has one member*, not *this user is its only member*.**

A colleague who stayed behind is the sampled member, so the transfer sweeps their directory into the new org. [`OrganizationsRepository.ts:357`](<permalink>) takes `userId` for the log context only.

Fix: `sample.data.length === 1 && sample.data[0]?.user_id === userId && !sample.hasNextPage()`
Repro: `pnpm vitest run OrganizationsRepository.test.ts -t "sole member"` → red (returns `true` for a two-member org)

<details><summary>Why</summary>

**Mechanism** — the two or three sentences the claim rests on, and why the smallest fix is this one.

**Detail** — the second call site, the library at a version, the live config, the alternative you rejected.

**Takeaway** — one line: the rule, not this instance.

**Not verified** — one line; omitted when there is nothing.
</details>
```

- **Three sentences above the fold, hard cap** — `claim` + `failure` together. The renderer counts them
  and warns. Everything the cap squeezes out goes to `why.detail`; nothing gets deleted for length.
- **`claim` is a sentence, not a topic.** "`isSoleMember` answers *has one member*, not *this user is its
  only member*" — not "problem with isSoleMember".
- **`failure` is one breath**: the state that produces the failure, what the user or the system ends up
  with, then the cite. Never "could cause issues".
- **`why` is uncapped but structured.** `mechanism` and `takeaway` are required, `detail` and
  `not_verified` are droppable, the order is fixed. A table earns a place in `detail` when the claim is a
  before/after or a matrix of cases, a mermaid diagram when it's a flow with a branch that matters.
- **`fix` is one fix, not a menu.** The smallest change that closes it, as a line of code where it fits.
  Rejected alternatives go in `why.detail`.
- **`takeaway` is the payload, and it is one line.** The rule the author can carry to the next PR:
  "a feature flag on a component gates the view, never the mutation — the write needs its own check", not
  "you should have guarded the handler". A finding with no generalisable rule is usually a finding that
  should have been `non-blocking`.
- **Provenance is recorded, never inferred.** `flagged_by` changes when the reviewer's own crit comment
  becomes the finding, or when it builds on an earlier round (`@ylkhayat, round 1`). `endorsed_by` grows
  only when someone says so on the thread — a dismissal deletes the record, agreement adds a name.
- **One finding per fix.** If two would be closed by the same edit, they are one record — fold the second
  in as a clause rather than opening a second thread.
- **One SCOPE record per cluster.** The root hunk is the record; everything that exists only to serve
  it is a `drops_with` entry, not a thread. `fix` renders as `Home:` there — where the change goes
  instead, not how to repair it.
- **A DEAD record needs `repro`, and `fix` renders as `Delete:`** — name what goes with it (the export,
  its docblock, its tests) rather than how to repair it. `repro` is the search that found no
  counterparty; `render.py` refuses the record without it. Like SCOPE it is exempt from the `why`
  toggle — the grep is the proof, and an essay defending a deletion is the thing the cap prevents.

## Other reviewers come first

Whatever anyone else already said — a human reviewer, cursor[bot], bugbot — is on the record before you
are. Read every existing comment from Phase 0 before authoring, and never restate one as if it were
yours. Each one that touches your review gets exactly one of two responses, as a **reply on that thread**
(a record with `reply_to` set — never a new comment on the same line):

| Response | When | Must carry |
|---|---|---|
| **Endorsed** | You agree | What their comment doesn't already say — the consequence they left implicit, the second call site, the severity you'd give it. One or two lines. |
| **Not endorsed** | You disagree, or it doesn't apply here | The reason, with evidence at `path:line`. "It reads that way, but `X` is already awaited on line 40." Never a bare disagreement. |

- **Silence is not an option for anything you'd otherwise have flagged.** If a finding of yours overlaps an existing comment, it is a reply — endorsed or not — not a fresh finding.
- **Endorsing costs a line, not a thread.** No badges, no shape, no toggle. A repeat of their point in your own words with a badge on it is the failure mode this exists to prevent.
- **Not endorsed is a real position, so it needs a real reason.** "Deferred to #NNNN in the stack" and "that code predates this PR" are reasons. "I'd do it differently" is not — drop it instead.
- Explicit author justifications ("deferred", "per spec") settle the thread. Note them and move on.
- Bot comments get the same treatment, and are worth endorsing when they're right — a bot finding nobody vouched for tends to get skimmed past.
