---
name: revise
description: Work on your own code — review local changes with crit, or close out reviewers' threads on your open PRs. With no argument it finds the PRs across your repos where feedback is waiting on you and lets you pick. One selection runs the crit loop you drive in the browser; several fan out one agent per PR. Pass `--autonomous` to drop the human gate.
argument-hint: "[base ref | pr refs: 123 #123 owner/repo#123 url] [--autonomous] (default: pick from the PRs waiting on you)"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, Agent
---

Everything on the author's side of your own code: review local changes before anyone sees them, or take
the review threads sitting on your open PRs and close them out. Two skills, split on whose code it is —
**`/review-pr` reviews someone else's PR and never touches code; this one only ever touches yours.**

**Repo- and team-specific values — repos, tooling commands, convention files — live in
`../review-exchange/config.md`.** Read it before the picker. It is the only file to edit to run this skill
against a different codebase.

**Never write a file into the checkout.** No `.review/`, no scratch JSON, no repro script, no
worktree under the repo — the reviewer's `git status` must stay clean and nothing here is worth a
`.gitignore` entry. Everything transient goes under `$REVIEW_STATE/revise/`.

**`$REVIEW_STATE` is `${XDG_STATE_HOME:-~/.local/state}`**, or whatever `REVIEW_STATE_DIR` is set
to. The scripts resolve it themselves; it is written this way here so nothing assumes one agent
harness's config directory.

**Load the review-exchange skill before authoring a finding or drafting a reply.** It is the contract the
two skills share: the two badges a finding carries, the verdict badge an answer carries, which answers a
given ask accepts, the confidence ladder, the cite rules, the marker, and who resolves. This file never
restates it — a rule about the vocabulary or the reply shape gets fixed there, and both skills inherit
the edit.

A PR you did not author is never this skill's work. Check it and stop:

```bash
[ "$(gh pr view <n> --json author -q .author.login)" = "$(gh api /user -q .login)" ] || echo "not yours"
```

## The one rule: never rewrite published history

Amending a branch that is already on the remote rewrites the shas every reviewer comment is anchored to.
GitHub marks all of them outdated and the discussion detaches from the code it was about. So:

```bash
git branch -r --contains <sha>    # non-empty → published → it only ever gains a commit
```

- **Unpushed** — amend into the commit that introduced the line, then `gh stack rebase --upstack`.
- **Published** — one new commit covering that PR's fixes, and when Phase 6 sends it, a plain `git push`.
  No amend, no force, no rebase of the stack. A rejected push means `git fetch` and rebase your own commit
  onto the new head.

Everything below keys off that, and nothing overrides it.

## The other rule: nothing leaves the session until you are told

A fix directive in crit authorizes the **edit**, never the **publish**. "fix all", "fix it", "do it",
"go ahead", "yes" all mean change the code and come back. None of them means push a branch or post to
GitHub.

crit is the private working document; the remote and GitHub are surfaces other people read. A review is
still in progress until the human says it isn't, so publishing waits for words that only mean publish:

| The human says | You do |
|---|---|
| "fix all", "fix it", "do X instead", "yes" | edit, verify, commit **locally**, draft the replies, report, wait |
| "post", "submit", "push", "publish", "send it" | push the branch and post the drafted replies — Phase 6 |
| "done", "wrap up" | summarize and `crit stop`; publish only if they also said to |

Nothing in the ambiguous middle counts. A question ("is this efficient?", "why?") is a question: answer
it in crit and keep waiting. Finish Review is not consent either — **it starts the next round, it does
not end the review.** Rounds are cheap and unlimited; an unwanted push cannot be taken back.

**"Prepared" is not "half done."** Reporting a round means the edits are applied, the verification has
run, a local commit exists, and every GitHub reply is written to a file ready to `--input`. Publishing is
then one command per artifact with no thinking left in it.

A local commit or amend is not a publish and needs no permission. **`git push`, `gh api` against a PR,
and `gh pr` anything are.** About to run one without having been told to? That is the mistake this rule
exists to stop.

`--autonomous` is the only exception: no human is in the loop to say "post", so it publishes on its own.

## The three shapes

How many PRs are in play decides the shape. There is no mode flag for it:

| In play | Work-list | crit | Commits | GitHub |
|---|---|---|---|---|
| **nothing** — local changes | Claude's own findings | yes | amend + restack | nothing |
| **one PR** | that PR's unresolved threads | yes | new commit, pushed on your word | replies drafted, posted on your word, threads left open |
| **several PRs** | each PR's unresolved threads | no | new commit per PR, pushed on your word | replies per PR, posted on your word |

**Several PRs → read `FLEET.md` in this directory** and run the fan-out there. The rest of this file is
the crit loop, which covers the first two.

**Several PRs means threads only.** An agent fixes what a human actually asked for, so every diff traces
to a thread id; a fresh finding it spots goes in the report, never into a commit.

The crit review file is a private working document between you and Claude, so findings themselves need
no attribution marker — `--author 'Claude Code'` already carries it inside crit. **Anything posted to
GitHub does:** load `/ai-ethics` for the reply template below, and for any text you lift out of a review
onto a surface other people read.

## Autonomous mode (`--autonomous`)

**Default is interactive** — crit opens, you read, you click Finish Review. `--autonomous` anywhere in
`$ARGUMENTS` drops the human out of the loop, for unattended runs (a headless skill like
`/desktop-execute`, a `/loop`, a cron). Strip the flag before parsing the rest of `$ARGUMENTS`.

It means exactly one thing — **no human in the loop** — and it is orthogonal to the shape. On a
several-PR run it is a **silent no-op**: a fan-out is already unattended, because crit cannot gate eight
branches at once. Don't error on it, don't mention it.

What changes, and only this:

- **No crit at all.** Skip Phase 1 (daemon, browser, port), the `crit comment` authoring in Phase 2,
  the crit replies in Phase 4, and Phase 5's relaunch. The work-list lives in your own working notes.
- **Never wait for Finish Review.** There is no round to submit and nothing to poll. You author the
  findings and act on them in the same pass.
- **Publishing needs no instruction here**, because nobody is present to give one: run Phase 6 yourself
  once the rounds are done. This is the single exception to the publish gate, and it exists only because
  waiting for a word that will never arrive would strand the work unpushed.
- **You are both sides, so the ask axis replaces consent.** Fix your own `blocking` findings — HIGH and
  MEDIUM. Anything that changes design, public shape, file layout, or dependencies — plus every
  `question` you cannot close with evidence, every `non-blocking`, and **every SCOPE finding,
  whose whole content is a judgement about what the branch is for** — is NOT yours to settle alone:
  leave the code as it is and report it to the caller (a blocking question, a PR-body line, whatever the
  calling skill does with it). An unattended guess is the failure mode this flag has to avoid, so when in
  doubt, don't touch it.
- **Two rounds is the ceiling.** Review → fix → re-review once if the fixes were substantive, then
  stop and report. No loop-until-clean without a human to end it.

Everything else holds unchanged: Phase 0's range, Phase 2's finding bar (severity + category, a
concrete failure, an evidence `path:line` you actually read, a red `Repro:` on every HIGH, one
smallest fix — **no evidence line means it is not a finding**), Phase 4's fix bar (minimal, in-diff,
no new deps, no refactors, the repro re-run green, amended into the commit it belongs to +
`gh stack rebase --upstack`), and the final summary. Unattended, red-then-green is the only thing
standing in for the human's review of the edit, so a HIGH without a repro is not one to fix
alone — report it instead.

On a single PR the same escalation rule decides what a reply may say: a thread you cannot close with
evidence gets `needs your call`, not a guess dressed up as an answer.

The interactive loop below is **hybrid and human-gated**: Claude reviews the branch's changes and posts its findings as crit inline comments; you read them in the browser, reply, dismiss, or add your own comments, then click **Finish Review**. That submit is the trigger. On each round Claude reads every comment and acts on its **intent**:

- **Question / discussion** ("why?", "is this needed?", "shouldn't X already handle this?") → investigate and reply with concrete context. No code change.
- **Acknowledgement / change request** ("yes, fix", "good catch", "do X instead", or your own directive comment) → fix the code in the spirit below, then reply noting what changed and where.
- **Dismissed** ("ignore", "fine", "not an issue") → drop it.

Fix everything that is actionable and not dismissed; answer everything else. Then loop — show the round's fixes, let the discussion continue — until no actionable comments remain.

Launch crit **once**, up front, and reuse that single daemon (one stable port) for the whole loop. crit live-reloads (0.16.x through 0.18.x) `review.json`, so comments and replies you author headlessly appear in the open browser immediately. Relaunch only when the head moves (it does after each fix round — see Phase 5) or the daemon dies.

You are NOT here to refactor or improve style — flag and fix clear, actionable problems only.

## Phase 0: Gather context and compute the range

Strip `--autonomous` first, then read what's left:

- **PR references** — `123`, `#123`, `owner/repo#123`, a full PR URL, in any mix. Bare numbers resolve
  against `gh repo view --json owner,name`. One reference → the single-PR shape below. More than one →
  `FLEET.md`.
- **A ref** (`develop`, a sha) → local changes against that base.
- **Empty** → **run the picker.** Not "review the current branch against the trunk" — an empty argument
  is a question, and the picker answers it.

### The picker (empty `$ARGUMENTS`)

One call covers every repo you work in. The repos come from the `repos` row of `../review-exchange/config.md` —
add them there, not here:

```bash
gh api graphql -f q='is:pr is:open author:@me repo:acme/web repo:acme/desktop-app'   # one repo: per config row -f query='
query($q:String!){ search(query:$q, type:ISSUE, first:50){ nodes{ ... on PullRequest {
  number title isDraft reviewDecision updatedAt repository{nameWithOwner}
  reviewThreads(first:100){nodes{isResolved}} }}}}'
```

**Keep a PR when it has at least one unresolved thread, or `reviewDecision == CHANGES_REQUESTED`.** Never
filter on `reviewDecision` alone: an `APPROVED` PR with unresolved threads still on it is the single most
forgotten case, and a PR whose reviewer commented without submitting a review has no decision at all.
Both are real work and both vanish from a decision-only filter.

Offer them through a multi-select question (whatever your agent offers for that), ordered by unresolved count descending,
one line each: `owner/repo#N — N unresolved · <decision> · <title>`. Four options per question and four
questions is **16 slots**; past that, offer the top 16 and say how many were left out. Never truncate in
silence.

Then one line, listing but **not** offering: `N PRs are assigned to you but authored by someone else —
those are /review-pr jobs`. An author-side agent must never touch a colleague's branch, and
`assignee:@me` is full of PRs that are reviews for you to do, not work for you to land.

Confirm the selection back in one line per PR before touching anything.

### With one PR selected

1. Confirm it's yours (the check at the top of this file). Not yours → stop, point at `/review-pr`.
2. Check out the head in a worktree and reset to `origin/<branch>` — these branches get force-pushed
   under you, and a stale local copy silently rebuilds the wrong thing. crit anchors to lines on disk, so
   `git rev-parse HEAD` must equal `headRefOid`.
3. Base the range on the PR's own refs so it matches what GitHub shows:
   `base=$(git merge-base <baseRefOid> <headRefOid>)`.
4. **Pull the work-list.** The unresolved threads (query in `../review-exchange/references/github-review-api.md`), plus
   every non-empty review body and PR-level comment — those carry asks with no anchor, which is exactly
   why they get dropped: no thread means nothing marks them undone. Read the **current file on disk** at
   each `path`, not the hunk quoted in the comment; branches move, and half of these are already fixed.
   Sort every item into one of five classes:

   | Class | Means |
   |---|---|
   | **fix** | The comment is right and the code still has the problem. |
   | **already fixed** | A later commit did it. Reply with the commit, change nothing. |
   | **won't fix** | Wrong, out of scope, or belongs to another PR in the stack. Reply with the reason. |
   | **needs the user** | You can't tell what they want, or it's a product call. **Ask.** Never invent an answer to a question asked of a human. |
   | **noted, deferred** | A conditional deferral whose condition hasn't fired ("worth a sentence when this file is next touched"). Record it, leave it alone. |

   **At six threads or more, fan the classification out** — it is N independent "read this file at this
   line, does the comment still hold?" jobs and nothing in it is sequential. One `haiku` agent per batch
   of three threads, all dispatched in one message, each handed the thread bodies, the worktree path and
   the `$SHARED_CONVENTIONS` path built below, each returning `{thread_id, class, evidence, current_code}` and **nothing
   else** — no prose summary, which is how the file contents get back into your context by another
   route. Below six, do it yourself; the briefing costs more than the read. The agents are strictly
   read-only: no edit, no commit, no crit call. **The class is yours to accept** — an agent that says
   `already fixed` without a `path:line` you can see has classified nothing.

   Bot comments (`*[bot]`) get the same treatment but rank below humans — when they disagree, the human
   wins. A reviewer's factual claim about another system ("that scheme isn't registered", "that endpoint
   is dead") is checkable: check it against the sibling repo, the API, the config file, before you fix or
   decline. Being right about it is the whole value of the reply.

```bash
base=$(git merge-base develop HEAD)   # or: git merge-base <arg> HEAD
git log --oneline --reverse "$base"..HEAD
```

Gather the conventions once — they apply to every commit, they change about monthly, and they are
re-read on every single run. **Cache them to a file and pass agents the path, never the contents**;
pasting 30KB of markdown into eight briefs pays for the same bytes eight times.

```bash
P=('docs/conventions/*.md' '.cursor/BUGBOT.md' '*/.cursor/BUGBOT.md')   # config's `convention files`
mkdir -p $REVIEW_STATE/revise
key=$(git ls-files -s "${P[@]}" | git hash-object --stdin)   # changes when any file, or the set, does
SHARED_CONVENTIONS=$REVIEW_STATE/revise/conventions-$key.md
[ -s "$SHARED_CONVENTIONS" ] || git ls-files -z "${P[@]}" \
  | xargs -0 awk 'FNR==1{printf "\n===== %s =====\n", FILENAME}1' > "$SHARED_CONVENTIONS"
```

Feed the patterns straight to `git ls-files` — **never through an unquoted `$files`**. This runs under
zsh, which does not word-split unquoted parameters, so a captured list arrives as one filename and the
key silently becomes the empty-blob hash.

The key is a content hash, so a stale cache is impossible and there is nothing to invalidate — an edit
to any convention file writes a new path. Old ones are junk in a scratch dir, not a correctness problem.

Compute the crit review range — everything on this branch that isn't on the base:

```bash
head=$(git rev-parse HEAD)
range="$base..$head"
```

Always review this concrete range (not `--pr`/`--base-branch`) — it forces crit onto the git diff path (`mode: git`) and matches exactly what the branch changed. Sanity-check the file list against `git diff --name-only "$base"..HEAD` before launching.

**Commit or stash first.** The range is commit-to-commit, so uncommitted work in the tree is invisible to it — and crit anchors comments to lines *on disk*, so a dirty tree also makes the anchors lie. Either commit the work under review (`gh stack add -Am "..."`, per the `commit-with-stack` skill) or review the working tree instead with a bare `crit`.

**Record whether the head is published** — `git branch -r --contains "$head"` — and carry it into Phase 4. It decides amend-versus-new-commit, and it is not something to re-derive later under time pressure.

If `node_modules` is missing and you need dependency types/implementations, run config's `install` (background) rather than guessing.

## Phase 1: Launch the single crit session (interactive only — `--autonomous` skips to Phase 2)

Start the daemon **once**, before authoring anything, so you can begin reading immediately:

0. **Ensure exactly one crit session for this working directory first** — `grep -l "$(pwd)" ~/.crit/sessions/*.json`, then `crit stop`/`kill` the stale PIDs and `rm` their session JSON so one remains. A shadowing daemon silently breaks comment visibility; the mechanics are in `../review-exchange/references/crit-mechanics.md`.
1. Launch `crit --range <base>..<head>` (the range from Phase 0) with `run_in_background: true`; let it open the browser (do **not** pass `--no-open` on the first launch).
2. Capture the port from `Started crit daemon at http://localhost:PORT` (also in `~/.crit/sessions/<review-id>.json`). **Note it — you reuse it for the whole loop.**
3. Relay the URL: "Crit is open at http://localhost:PORT — start reading; my findings will appear as I add them. Reply, dismiss, or add your own comments, then click Finish Review and I'll act on everything."

The daemon keeps the background task alive until you click **Finish Review**, which completes the round.

## Phase 2: Review and author findings (live)

**On a single PR, the reviewers' threads are the work-list and they come first.** Author each one into
crit as a comment **attributed to the reviewer who raised it** (`--author '<their login>'`) so the browser
shows who actually asked, with your classification and the evidence you gathered in the body. Then, and
only then, add findings of your own — and **never re-flag what a reviewer already raised**, or propose a
change that reverses a decision a reviewer accepted. Their thread is the record; yours is an addition to
it.

Read the changed files (not just the diff). For each changed file check:

- **Logic & Correctness**: off-by-one, wrong comparisons, inverted conditions, missing null/undefined checks, unhandled promise rejections or missing awaits, race conditions, wrong variable (copy-paste), missing/incorrect returns, incomplete switch/if-else chains.
- **Runs twice**: what happens if this operation runs again, or resumes after a previous run died halfway? "It depends what state was left behind" is a missing reconciliation step, and on an at-least-once trigger (a webhook, a queue, a retry) it is a HIGH. Where two actors can touch the same mutable state, look for a lock, a sequential phase, or exclusive ownership — a convention someone has to remember is not serialization.
- **Edge Cases**: empty arrays/strings/zero values, concurrent or duplicate calls, large inputs and boundary values, missing error handling for external calls (DB/API/third-party), actually-missing optional fields.
- **Security (OWASP-aware)**: injection (SQL/NoSQL/command/XSS), missing input validation or sanitization at boundaries, sensitive-data exposure (logging secrets, returning internal errors), missing or incorrect authorization, insecure direct object references, missing rate limiting on new endpoints.
- **Convention Violations**: every rule in config's `convention files`. Flag clear violations only.
- **Scope**: does every hunk serve what this branch set out to do? A hook nothing calls, a drive-by
  rename, scaffolding for a later ticket — file it as SCOPE, never as a severity. The exclusion list
  that keeps this from being noise, and the transitive closure that collapses a chain into one
  finding, are in `../review-pr/references/scope-lens.md`; read it before filing one.
- **Dead counterparty**: does every guard, helper, fallback arm and compat shim have something on the
  other end of it? A guard with no threat, an exported predicate with no caller, a fallback for a field
  nothing emits — name the counterparty and grep for it, counting test files out. The counterparty
  table, the never-simplify exclusions and the earlier-round exception are in
  `../review-pr/references/deletion-lens.md`; the grep is the evidence, so read it first.
- **API & Data**: breaking API changes without migration, missing validation on new request/response schemas, missing indexes for new query patterns, N+1 queries.

Read surrounding source for context before flagging — the "bug" might be handled elsewhere. Only flag **real issues**, not style preferences or theoretical concerns. When unsure, frame the finding as a question rather than a definitive claim.

### Finding shape

Same two badges as `/review-pr` files, so a finding reads the same whichever side raised it —
the **review-exchange** skill owns them, plus the ladder and the cite rules. On top of the badges this skill
adds one category tag for its own triage: `[Logic]`, `[Edge Case]`, `[Security]`, `[Convention]`,
`[API]`, `[Scope]`. A `[Scope]` finding carries the scope badge **in place of** a severity and is
always `non-blocking` — there is no HIGH scope finding.

```markdown
![HIGH](…) ![blocking](…) `[Logic]` **<the claim, one sentence.>**

<What breaks: concrete state or inputs, then the wrong outcome. One or two sentences, with the cite.>

Fix: `user.pictureUrl = event.user.picture ?? null`
Repro: `pnpm vitest run commitSession.test.ts -t "clears picture"` → red (`pictureUrl` keeps the old URL)

<details><summary>Why</summary>

**Mechanism** — `event.user.picture` is `nullish()`, and mongoose strips `undefined` out of the update.

**Takeaway** — a field that can be cleared upstream needs an explicit null, not an absent key.
</details>
```

- **Three sentences above the fold, hard cap** — the claim plus the failure. Everything else goes in the
  toggle; nothing gets dropped for length.
- **The claim is a sentence, not a topic.** "a field cleared at the IdP is silently never unset" — not
  "issue with the update".
- **The failure is concrete.** The state that produces it, then what the row or the user ends up with.
  Never "could cause issues".
- **One fix, not a menu.** The smallest change that closes it, as a line of code where it fits.
- **`Why` is uncapped but structured** — `Mechanism`, then `Detail` / `Takeaway` / `Not verified` as they
  earn it. Leave a blank line after `<summary>`, and a blank line between the labels, or GFM runs them
  together on one line.

Read surrounding source before flagging — the "bug" might be handled elsewhere. Only flag **real
issues**, not style preferences or theoretical concerns.

Author into the running session — **no restart needed** (`--autonomous`: skip this block entirely,
keep the findings in your own notes and go straight to Phase 4):

1. Author all findings in **one** bulk call — `crit comment --json --file <path> --author 'Claude Code'`; entry shape, quoting and line-numbering rules are in `../review-exchange/references/crit-mechanics.md`. Each body is the shape above: the two badges, the category tag, the claim, the failure, the fix, the toggle.
   - Include one review-level comment summarizing what you reviewed.
   - **A comment whose `focus_key` lands `null` is invisible in the browser** even though `crit status` counts it. If `crit comment` prints `Note: ... no daemon running`, stop and fix daemon resolution (Phase 1 step 0) before continuing — never hand-edit `focus_key`.
2. **Verify the reviewer can see them** — crit's own count isn't enough. Run the verification steps in `../review-exchange/references/crit-mechanics.md`: `/api/file/comments?path=<file>` per file, `/api/session` `review_comments`, and a non-null `focus_key` on every entry in `review.json`.
3. Tell the reviewer the findings are in (same URL), to reply/dismiss/add comments, and click **Finish Review**. Wait for the background `crit` task to complete — do not poll, do not proceed early.

## Phase 3: Process the round by intent (on Finish Review — interactive only)

When the round completes, read `review.json` and classify **every** comment — your findings, the reviewer's replies to them, and the reviewer's own new comments:

- **Question / discussion** → investigate (read code, installed package types/runtime behavior, codebase conventions) and reply with concrete evidence via a `reply_to` entry. No code change. If the evidence materially changes a finding, rewrite that comment's body (jq/Python) so it stands alone, and say so in the reply.
- **Acknowledgement / change request / the reviewer's own directive comment** → mark for fix. Capture the exact direction (e.g. "use X instead", "make it explicit").
- **Dismissed** → drop (remove at the next quiet point; don't fix).
- **Your own `blocking` findings the reviewer didn't touch** and that are clearly actionable → treat as change requests. Fix everything actionable and not dismissed.

`question` and `non-blocking` findings are surfaced, not auto-fixed, unless the reviewer asked.
**SCOPE included, and with no reading under which it is not** — deleting your own code because an
agent judged it off-ticket is the failure this rule exists to stop. Report it; they decide.

### Discuss first, fix when the thread settles

A thread is a conversation until it resolves into a decision, and **only a decision produces code**.
Rounds are cheap; a wrong edit costs a re-review.

- **Still open → don't touch the code.** A thread whose latest comment is a question, a challenge to
  your reasoning, or a request for context gets a reply with evidence and nothing else — not even a
  "helpful" partial edit. Being asked *why* you'd change something is not permission to change it.
- **Unsure whether it's settled? Propose, don't apply.** Reply with the exact change you would make —
  a short diff sketch or the replacement lines — and ask for a yes. That reply *is* the round's work.
  It costs one more Finish Review and removes all guessing.
- **Settled → fix it, quote the direction.** Any acknowledgement (`yes`, `do it`, `fine`, `agreed`,
  `go ahead`) or a directive (`use X instead`, `make it explicit`, `move this to main`) closes the
  thread and hands you the instruction. Follow that instruction, not your original proposal, where
  the two differ — the reviewer's version wins even if yours seemed better. Then reply with
  `file:line` and what changed.
- **Reversal beats consistency.** If the discussion shows a finding was wrong, say so plainly, drop
  it, and revert any earlier edit made for it. Never defend an edit because it's already applied.
- **Silence is consent for clear-cut bugs only.** A `blocking` HIGH or MEDIUM the reviewer read and
  didn't object to gets fixed — that's the rule above, and it keeps the loop from stalling on obvious
  breakage. Everything else waits for a directive: `question`s, `non-blocking`s, and anything that
  changes design, public shape, file layout, or dependencies. When in doubt which bucket a finding is
  in, it's the second one.

## Phase 4: Fix

Fix directly on the branch under review. For each actionable item, read the relevant source
file, understand the surrounding code, and make a **minimal, targeted** change. Where the
reviewer gave a direction, follow it exactly. Do not refactor, rename, or touch files outside
the range's diff; do not add dependencies. If unsure a fix is correct, leave it as an Open
question instead.

**A finding that carried a `Repro:` gets it re-run after the fix.** Green is the proof the edit landed
where the claim was, so quote it in the crit reply alongside the `file:line`. Then delete the scratch
harness — or keep it, as a real test in the suite's own convention, when the case it covers deserves
one. A fix whose repro stays red is not fixed: revert the edit and reopen the thread.

Then land them by the rule at the top of this file — **the head being published decides this, nothing else:**

**Unpushed head.** Into the commit it belongs to, not on top of it:

```bash
git commit -a --amend --no-edit     # the fix belongs to the commit under review
gh stack rebase --upstack           # REQUIRED after any amend — descendants are stale until this runs
```

If the branch isn't the tip of the stack, check it out first (`gh stack down` / `gh stack switch`), amend
there, then cascade. See the `commit-with-stack` skill.

**Published head — the single-PR shape.** One new commit for the whole round, and **stop there**:

```bash
git commit -am "<what the round fixed>"
# no push. Phase 6 pushes, on the human's word — plain, no --force, no amend, no restack.
```

Before `git add`, run the repo's own fix task over the tree — the `fix` row of `../review-exchange/config.md`
(`pnpm fix:all` here) — so formatting never lands in a follow-up commit. Then `git status --short`: it fixes the
whole tree, not your diff, so anything it reformatted that you didn't touch belongs to someone else's
commit. Restore those (`git checkout -- <path>`) and note the pre-existing drift in the summary. Never
reach for a formatter the repo hasn't configured.

Then **draft** one reply per thread you acted on, using the template below, and write each to its own
file under `$REVIEW_STATE/revise/<pr>/` (`reply-<thread>.json`, a `{"body": "..."}` object ready
to `--input`) — never inside the checkout, which would leave untracked files in the repo. Nothing
is posted in this phase. Report what the drafts say; Phase 6 sends them.

**Several branches with actionable items — fan out over worktrees.** Map each actionable comment
to the commit whose diff introduced that line (`git log -L`, or `git blame` on the line; if
ambiguous, the commit that last touched it). Then spawn one fix agent per branch with the Agent
tool and **launch them in parallel**, each in its own git worktree so they can't collide — the same
isolation `/desktop-execute` uses. Each agent's prompt:

---

**You are a code fix agent** working in an isolated git worktree.

Create your worktree outside the checkout and `cd` into it — nothing you write may show up in the
repo's `git status`:

```bash
wt=$REVIEW_STATE/revise/fix-<branch>
git worktree add "$wt" <branch>
cd "$wt"
pnpm install --prefer-offline   # config's `install`
```

**Issues to fix** (from the crit review — each is reviewer-confirmed or a reviewer directive):

<insert the actionable comments for this branch: file:line, category, what to change, and any reviewer direction verbatim>

**Conventions to follow:**

Read `$SHARED_CONVENTIONS` (one file, already assembled) and any per-directory convention file
alongside the files you touch. Do not expect them pasted here.

**Instructions:**

1. Read the commit under review for context: `git show <branch>`.
2. For each issue, read the relevant source file in the worktree, understand the surrounding code,
   and make a **minimal, targeted** fix. Where the reviewer gave a direction, follow it exactly.
   Where the issue came with a `Repro:` command, run it before the fix (confirm red) and after
   (confirm green), and report both. A repro still red after your edit means the fix is wrong —
   revert it and report the issue as unfixed.
3. Do not refactor, rename, or reorganize beyond what the fix needs. Do not modify files outside the
   commit's diff. Do not add dependencies or change package.json.
4. If you're unsure a fix is correct, leave it and record it under Open questions instead.
5. Amend the fix into the commit — **do not create a new commit, and do not rebase or push:**

```bash
git commit -a --amend --no-edit
```

6. Report back: per fix, `file:line`, category, what changed; plus any Open questions.
7. Clean up (the amended branch persists in the main repo): `cd` out, then
   `git worktree remove worktrees/fix-<branch>`.

---

A branch already checked out in the main checkout can't be checked out in a worktree — `git worktree
add` refuses it. That branch is simply the one the parent fixes directly (above); agents take the rest.

**Read each agent's diff, not its report.** An agent reports what it intended, which is not always what
it did: for every branch that got an agent, run `git show <branch>` and check the edit is the one the
comment asked for, in the file it named, with nothing else riding along. A repro the agent claims went
green gets re-run here. A report you can't confirm from the diff is an unfixed finding.

**Cascade once, after every agent has finished.** Each agent amends its own branch and nothing else;
the restack is the parent's job and must be serial — parallel `gh stack rebase` runs fight over the
same descendants and re-resolve the same conflicts. From the main checkout:

```bash
gh stack bottom && gh stack rebase --upstack
gh stack view          # confirm no branch still needs a rebase
```

Restacking is local, so it belongs here. Pushing the branches is not — that waits for Phase 6 like
everything else.

After fixing, reply in crit (interactive only) on each fixed comment via a bulk `crit comment --json --file ... --author 'Claude Code'` call with `reply_to` entries, noting the fix (`file:line`, plus one line on what changed). For questions you investigated, your Phase 3 replies already cover them.

### Reply template (single-PR shape)

**the **review-exchange** skill owns the reply shape and the verdict badges** — the badge line, the AI;DR, the
evidence toggle, the evidence line, which verdicts a given ask accepts, the rung a `won't fix` needs, and
the rule that the author never resolves. Load it and follow it; do not restate or adapt it here. Load
`/ai-ethics` for the marker at the same time.

What is this skill's, on top of that shape:

- **The evidence line carries the commit.** Anything you changed cites the short sha of the commit that
  carries it — that is what lets the reviewer see the fix without hunting: `37ad3509 ·
  apps/api/session/commitSession.ts:162`.
- **A `fixed` re-runs the finding's own repro and quotes it red-then-green.** Same command both times.
- **Draft, don't post.** Every reply is written to its own file ready to `--input`, and Phase 6 sends it
  on the human's word. A reply whose wording you would still be deciding is not drafted.
- **Body obligations have no root comment id**, so they get one PR-level comment of their own, drafted to
  its own file like the rest and sent by Phase 6
  (`gh api repos/{owner}/{repo}/issues/<n>/comments -f body='...'`). One line per item, same marker and
  same evidence discipline. Skip it entirely if every body item was already covered by a thread reply.

## Phase 5: Loop (`--autonomous`: no relaunch, no third round — summarize and go to Phase 6)

The fixes moved the head, so recompute the range and re-anchor crit:

1. Recompute `head`/`base`/`range` from Phase 0 against the new commits.
2. `crit stop` the current daemon first — the round moved the head, so relaunching without stopping leaves two sessions racing for this cwd. Then relaunch with `--no-open` (`run_in_background: true`), **with `CRIT_PORT` exported to the same value as the first launch** so the reviewer's open tab keeps working; crit re-randomizes the port otherwise, and the flag alone does not survive a reconnect. **Read the re-anchoring table in `crit-mechanics.md` before choosing the range**: relaunching on the *new* head hides the whole round's thread, so the default is to relaunch on the **original** range and tell the reviewer the diff pane is pre-fix. Re-verify with `/api/file/comments?path=<file>` (and confirm `grep -l "$(pwd)" ~/.crit/sessions/*.json` shows just one session).
3. Tell the reviewer the round is updated (same URL): fixes are in, replies are **drafted**, nothing is pushed or posted, open discussions remain — read and click **Finish Review** again.

Repeat Phases 3–5 on each Finish Review for as long as the reviewer keeps reviewing. **You do not decide
when this ends.** No actionable comments remaining is not the end — it is a quiet round; say so and wait.
The loop closes when they say "done" / "wrap up", or when they tell you to publish. Then give a summary:

```
## Review Summary: <base>..<head>

### <short sha> — <first line of commit message>   (omit the per-commit heading for a single commit)
**Fixed:**
- [Category] file:line — description of fix
**Open questions (require human judgment):**
- [Category] file:line — question and why it needs human input
**Held, waiting on your word:**
- <sha> — committed locally, not pushed
- <n> thread replies drafted at <paths>, not posted
```

That last section is the one to get right: it is the reviewer's only view of what is loaded and waiting.
Never report a round as finished while something in it is still held — say what is held and what sends it.

**Unpushed head:** fixes were amended in, so there are no separate fix commits to fold —
`git log --oneline "$base"..HEAD` shows the same commits as Phase 0 with new shas. Confirm
`gh stack view` reports no branch needing a rebase. Leave the daemon running; `crit stop` is Phase 6's.

**Published head:** the summary names the local sha, the threads each drafted reply answers and with
which verdict, the threads left for you (`needs your call`), and the body obligations with their
outcomes — deferred ones included, with what would trigger them. Every thread stays unresolved; say
which ones the fixes answer so the reviewer knows where to look.

## Phase 6: Publish, on their word and not before

Only from an instruction that can only mean publish — the middle row of the table at the top of this
file. Send what Phase 4 already prepared; **author nothing new here.** A reply whose wording you would
still be deciding is a reply that was never drafted, so go back to Phase 4 and draft it.

1. **Re-read the drafts before sending.** Rounds may have moved on since they were written: a thread that
   later got reversed, a `file:line` that shifted under a newer fix, a sha that is no longer the one that
   carries the change. Re-check each against the tree, and fix the draft rather than sending a stale one.
   **Then pull the work-list again** (Phase 0, "With one PR selected", step 4), because reviewers keep reviewing while the
   rounds run. Compare against the work-list you sorted. Anything new is any thread, comment, or review
   with a body, or any new commit on the remote branch. If something is new, stop: publish nothing,
   sort the new items into the round, and tell the human what arrived. A push on top of a review you
   never read answers a question nobody asked and leaves the one they did ask unanswered.
2. **Push**, by the rule at the top of this file — plain `git push` on a published head, `gh stack rebase
   --upstack` first when an amend moved descendants. A rejected push means `git fetch` and rebase your own
   commit onto the new head, never `--force`.
3. **Post the replies**, one per thread, `--input` from its drafted file. On a fan-out, one push and one
   reply set per PR.
4. **Body obligations** with no root comment id go in one PR-level comment — skip it when every item was
   already covered by a thread reply.
5. **Verify what landed, don't assume it.** `git rev-parse HEAD` against the remote ref, and re-read the
   threads to confirm each reply is where you meant it (`gh api` per the thread query) — a reply can land
   as a parallel thread, which is the failure the replies endpoint exists to avoid.
6. Report the published shas and reply URLs. Then `crit stop`, and remove the worktree if the review used
   one.

Every thread stays **unresolved** — the reviewer resolves it, and that is how they see the reply.

## Mechanics

**The exchange contract — the **review-exchange** skill, before the first finding and the first reply.** The
badges, the verdict table, the ladder, the cite rules, the reply shape, the marker, who resolves. Shared
with `/review-pr`, which raises the threads this skill answers.

**crit — `../review-exchange/references/crit-mechanics.md`, before the first `crit` call.** Single-session precondition,
the `focus_key` trap that hides comments from the browser, the verification endpoints, authoring via
`--file`, how to delete a comment, and two things worth knowing before the first round: **pin the port
with `CRIT_PORT`** so a restart keeps the reviewer's tab, and **the finish handshake** — a finish with
open comments parks the reviewer in "Waiting for your agent to finish..." until an agent re-enters
`/api/review-cycle`, and the global finish hook is what makes their click survive a dead listener.

**GitHub review API — `../review-exchange/references/github-review-api.md`, before the first `gh api` call against a
PR's reviews.** The thread query, the REST/GraphQL id bridge, the replies endpoint, outdated anchors.
Shared with `/review-pr`, which works the reviewer's side of the same threads.

Fix a gotcha in those files, not here.
