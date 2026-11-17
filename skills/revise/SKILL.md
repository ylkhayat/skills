---
name: revise
description: Work on your own code — review local changes with crit, or close out reviewers' threads on your open PRs. With no argument it finds the PRs across your repos where feedback is waiting on you and lets you pick. One selection runs the crit loop you drive in the browser; several fan out one agent per PR. Pass `--autonomous` to drop the human gate.
argument-hint: "[base ref | pr refs: 123 #123 owner/repo#123 url] [--autonomous] (default: pick from the PRs waiting on you)"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, Agent
---

Everything on the author's side of your own code: review local changes before anyone sees them, or take the review threads on your open PRs and close them out. **`/review-pr` reviews someone else's PR and never touches code; this one only ever touches yours.**

**Repo- and team-specific values (repos, tooling commands, convention files) live in `../review-exchange/config.md`.** Read it before the picker.

**Never write a file into the checkout.** No `.review/`, scratch JSON, repro script, or worktree under the repo. Everything transient goes under `$REVIEW_STATE/revise/`.

**`$REVIEW_STATE` is `${XDG_STATE_HOME:-~/.local/state}`**, or whatever `REVIEW_STATE_DIR` is set to.

**Load the review-exchange skill before authoring a finding or drafting a reply.** It owns the badges, verdict badges, which answers an ask accepts, the confidence ladder, cite rules, marker, and who resolves. Fix vocabulary and reply-shape rules there, not here.

A PR you did not author is never this skill's work. Check it and stop:

```bash
[ "$(gh pr view <n> --json author -q .author.login)" = "$(gh api /user -q .login)" ] || echo "not yours"
```

## The one rule: never rewrite published history

Amending a pushed branch detaches every reviewer comment from its code.

```bash
git branch -r --contains <sha>    # non-empty → published → it only ever gains a commit
```

- **Unpushed** — amend into the commit that introduced the line, then `gh stack rebase --upstack`.
- **Published** — one new commit covering that PR's fixes; Phase 6 sends it with a plain `git push`. No amend, no force, no rebase of that branch. A rejected push means `git fetch` and rebase your own commit onto the new head.
- Rebasing your own *descendant* branches onto the parent's new head is allowed once the parent is pushed (see Phase 6 step 6); it never touches the parent's reviewed shas.

## The other rule: nothing leaves the session until you are told

A fix directive authorizes the **edit**, never the **publish**.

| The human says | You do |
|---|---|
| "fix all", "fix it", "do X instead", "yes" | edit, verify, commit **locally**, draft the replies, report, wait |
| "post", "submit", "push", "publish", "send it" | push the branch and post the drafted replies — Phase 6 |
| "done", "wrap up" | summarize and `crit stop`; publish only if they also said to |

Questions are questions: answer in crit and keep waiting. Finish Review is not consent; **it starts the next round.** An unwanted push cannot be taken back.

Reporting a round means edits applied, verification run, a local commit exists, and every GitHub reply is written to a file ready to `--input`. A local commit or amend needs no permission. **`git push`, `gh api` against a PR, and `gh pr` anything are publishes.**

`--autonomous` is the only exception.

## The three shapes

| In play | Work-list | crit | Commits | GitHub |
|---|---|---|---|---|
| **nothing** — local changes | Claude's own findings | yes | amend + restack | nothing |
| **one PR** | that PR's unresolved threads | yes | new commit, pushed on your word | replies drafted, posted on your word, threads left open |
| **several PRs** | each PR's unresolved threads | no | new commit per PR, pushed on your word | replies per PR, posted on your word |

**Several PRs → read `FLEET.md` in this directory** and run the fan-out there. The rest of this file is the crit loop.

Several PRs means threads only: every diff traces to a thread id; a fresh finding goes in the report, never into a commit.

Findings in crit need no marker (`--author 'Claude Code'` carries it). **Anything posted to GitHub does:** load `/ai-ethics` for the marker.

## Autonomous mode (`--autonomous`)

Strip the flag before parsing the rest. It means one thing, **no human in the loop**, and is a silent no-op on a several-PR run.

- No crit at all: skip Phase 1, crit authoring in Phase 2, crit replies in Phase 4, and Phase 5's relaunch. Keep the work-list in your notes.
- Never wait for Finish Review. Author and act in the same pass.
- Publish yourself via Phase 6 once rounds are done (the single exception to the gate).
- Fix your own `blocking` HIGH and MEDIUM findings. Anything that changes design, public shape, file layout or dependencies, every `question` you cannot close with evidence, every `non-blocking`, and **every SCOPE finding** is NOT yours to settle: leave the code and report it to the caller.
- Two rounds is the ceiling.
- A HIGH without a red `Repro:` is reported, not fixed.
- On a single PR, a thread you cannot close with evidence gets `needs your call`.

Phase 0's range, Phase 2's finding bar and Phase 4's fix bar hold unchanged.

## How the interactive loop works

Claude reviews the changes and posts findings as crit inline comments; you reply, dismiss or add comments in the browser, then click **Finish Review**. Each round Claude acts on each comment's **intent**:

- **Question / discussion** → investigate, reply with concrete context. No code change.
- **Acknowledgement / change request / your own directive** → fix, then reply with what changed and where.
- **Dismissed** → drop it.

Launch crit **once** and reuse that daemon (one stable port). crit live-reloads `review.json`, so headless comments appear immediately. Relaunch only when the head moves (Phase 5) or the daemon dies.

You are NOT here to refactor or restyle — flag and fix clear, actionable problems only.

## Phase 0: Gather context and compute the range

Strip `--autonomous`, then read what's left:

- **PR references** (`123`, `#123`, `owner/repo#123`, URL, any mix). Bare numbers resolve against `gh repo view --json owner,name`. One → single-PR shape. More → `FLEET.md`.
- **A ref** (`develop`, a sha) → local changes against that base.
- **Empty** → **run the picker.**

### The picker (empty `$ARGUMENTS`)

Repos come from the `repos` row of `../review-exchange/config.md`, one `repo:` term per row:

```bash
gh api graphql -f q='is:pr is:open author:@me repo:acme/web repo:acme/desktop-app' -f query='
query($q:String!){ search(query:$q, type:ISSUE, first:50){ nodes{ ... on PullRequest {
  number title isDraft reviewDecision updatedAt repository{nameWithOwner}
  reviewThreads(first:100){nodes{isResolved}} }}}}'
```

**Keep a PR when it has at least one unresolved thread, or `reviewDecision == CHANGES_REQUESTED`.** Never filter on `reviewDecision` alone: an APPROVED PR with unresolved threads, or a PR with comments but no submitted review, is real work.

Offer them through a multi-select question, ordered by unresolved count descending, one line each: `owner/repo#N — N unresolved · <decision> · <title>`. Max 16 slots; say how many were left out, never truncate silently.

Then one line, not offered: `N PRs are assigned to you but authored by someone else — those are /review-pr jobs`.

Confirm the selection back in one line per PR before touching anything.

### With one PR selected

1. Confirm it's yours. Not yours → stop, point at `/review-pr`.
2. Check out the head in a worktree and reset to `origin/<branch>`; `git rev-parse HEAD` must equal `headRefOid`.
3. `base=$(git merge-base <baseRefOid> <headRefOid>)`.
4. **Pull the work-list.** Unresolved threads (query in `../review-exchange/references/github-review-api.md`) plus every non-empty review body and PR-level comment — those have no anchor and get dropped. Read the **current file on disk** at each `path`, not the quoted hunk. Sort each item:

   | Class | Means |
   |---|---|
   | **fix** | The comment is right and the code still has the problem. |
   | **already fixed** | A later commit did it. Reply with the commit, change nothing. |
   | **won't fix** | Wrong, out of scope, or belongs to another PR in the stack. Reply with the reason. |
   | **needs the user** | You can't tell what they want, or it's a product call. **Ask.** |
   | **noted, deferred** | A conditional deferral whose condition hasn't fired. Record it, leave it alone. |

   **At six threads or more, fan the classification out:** one `haiku` agent per batch of three threads, all dispatched in one message, each handed the thread bodies, the worktree path and the `$SHARED_CONVENTIONS` path, returning only `{thread_id, class, evidence, current_code}`. Strictly read-only. **The class is yours to accept**: `already fixed` without a visible `path:line` is not a classification. Below six, do it yourself.

   Bot comments (`*[bot]`) rank below humans. A reviewer's factual claim about another system is checkable: check it against the sibling repo, API or config before you fix or decline.

```bash
base=$(git merge-base develop HEAD)   # or: git merge-base <arg> HEAD
git log --oneline --reverse "$base"..HEAD
```

Cache conventions to a file and pass agents the path, never the contents:

```bash
P=('docs/conventions/*.md' '.cursor/BUGBOT.md' '*/.cursor/BUGBOT.md')   # config's `convention files`
mkdir -p $REVIEW_STATE/revise
key=$(git ls-files -s "${P[@]}" | git hash-object --stdin)
SHARED_CONVENTIONS=$REVIEW_STATE/revise/conventions-$key.md
[ -s "$SHARED_CONVENTIONS" ] || git ls-files -z "${P[@]}" \
  | xargs -0 awk 'FNR==1{printf "\n===== %s =====\n", FILENAME}1' > "$SHARED_CONVENTIONS"
```

Feed the patterns straight to `git ls-files`, never through an unquoted `$files` (zsh does not word-split).

Compute the crit range:

```bash
head=$(git rev-parse HEAD)
range="$base..$head"
```

Always review this concrete range (not `--pr`/`--base-branch`). Sanity-check against `git diff --name-only "$base"..HEAD`.

**Commit or stash first.** Uncommitted work is invisible to the range and makes anchors lie. Commit (`gh stack add -Am "..."`, per `commit-with-stack`) or review the working tree with a bare `crit`.

**Record whether the head is published** (`git branch -r --contains "$head"`) and carry it into Phase 4.

If `node_modules` is missing, run config's `install` in the background.

## Phase 1: Launch the single crit session (interactive only)

0. **Ensure exactly one crit session for this directory** — `grep -l "$(pwd)" ~/.crit/sessions/*.json`, then `crit stop`/`kill` stale PIDs and `rm` their session JSON. Details in `../review-exchange/references/crit-mechanics.md`.
1. Launch `crit --range <base>..<head>` with `run_in_background: true`; let it open the browser.
2. Capture the port from `Started crit daemon at http://localhost:PORT`. Reuse it for the whole loop.
3. Tell the user: "Crit is open at http://localhost:PORT — start reading; my findings will appear as I add them. Reply, dismiss, or add your own comments, then click Finish Review and I'll act on everything."

## Phase 2: Review and author findings (live)

**On a single PR, the reviewers' threads are the work-list and come first.** Author each into crit as a comment **attributed to the reviewer** (`--author '<their login>'`) with your classification and evidence in the body. Only then add findings of your own — **never re-flag what a reviewer already raised**, or reverse a decision a reviewer accepted.

Read the changed files, not just the diff. Check:

- **Logic & Correctness**: off-by-one, inverted conditions, missing null checks, missing awaits, races, copy-paste variables, missing returns, incomplete switch chains.
- **Runs twice**: what if this runs again or resumes after dying halfway? "Depends on leftover state" is a missing reconciliation step, and a HIGH on an at-least-once trigger. Two actors on the same mutable state need a lock, sequential phase or exclusive ownership.
- **Edge cases**: empty/zero values, duplicates, boundaries, unhandled external-call errors.
- **Security**: injection, missing validation at boundaries, leaked secrets or internal errors, missing authorization, IDOR, missing rate limits on new endpoints.
- **Convention violations**: every rule in config's `convention files`; clear violations only.
- **Scope**: does every hunk serve what the branch set out to do? File drive-bys and scaffolding as SCOPE, never a severity. Read `../review-pr/references/scope-lens.md` first.
- **Dead counterparty**: does every guard, helper, fallback and shim have something on the other end? Name it and grep (tests excluded). Read `../review-pr/references/deletion-lens.md` first.
- **API & Data**: breaking changes without migration, unvalidated new schemas, missing indexes, N+1.

Read surrounding source before flagging; the "bug" might be handled elsewhere. Only real issues, not style or theory. When unsure, frame it as a question. **No evidence `path:line` you read means it is not a finding.**

### Finding shape

Same two badges as `/review-pr` (owned by review-exchange), plus one category tag: `[Logic]`, `[Edge Case]`, `[Security]`, `[Convention]`, `[API]`, `[Scope]`. A `[Scope]` finding carries the scope badge **in place of** a severity and is always `non-blocking`.

```markdown
![HIGH](…) ![blocking](…) `[Logic]` **<the claim, one sentence.>**

<What breaks: concrete state or inputs, then the wrong outcome. One or two sentences, with the cite.>

Fix: `profile.nickname = input.nickname ?? null`
Repro: `pnpm vitest run saveProfile.test.ts -t "clears nickname"` → red (`nickname` keeps the old value)

<details><summary>Why</summary>

**Mechanism** — `input.nickname` is optional, and the ORM leaves `undefined` out of the update.

**Takeaway** — a field the user can clear needs an explicit null, not an absent key.
</details>
```

- Three sentences above the fold, hard cap. The rest goes in the toggle.
- The claim is a sentence, not a topic. The failure is concrete, never "could cause issues".
- One fix, not a menu. A HIGH carries a red `Repro:`.
- `Why` is structured: `Mechanism`, then `Detail` / `Takeaway` / `Not verified`. Blank line after `<summary>` and between labels.

Author into the running session (autonomous: skip, keep notes):

1. One bulk call: `crit comment --json --file <path> --author 'Claude Code'` (entry shape and quoting in `crit-mechanics.md`). Include one review-level summary comment.
   - A comment whose `focus_key` is `null` is invisible in the browser. If `crit comment` prints `Note: ... no daemon running`, fix daemon resolution (Phase 1 step 0); never hand-edit `focus_key`.
2. **Verify the reviewer can see them** with the steps in `crit-mechanics.md`: `/api/file/comments?path=<file>`, `/api/session` `review_comments`, non-null `focus_key` in `review.json`.
3. Tell the reviewer (same URL) to click **Finish Review**. Wait for the background crit task; do not poll.

## Phase 3: Process the round by intent (interactive only)

Read `review.json` and classify **every** comment — yours, the reviewer's replies, and their new ones:

- **Question** → investigate and reply with evidence via a `reply_to` entry. No code change. If the evidence changes a finding, rewrite its body and say so.
- **Acknowledgement / change request / directive** → mark for fix with the exact direction.
- **Dismissed** → drop.
- **Your own untouched `blocking` HIGH/MEDIUM** that is clearly actionable → fix.

`question` and `non-blocking` findings are surfaced, not auto-fixed, unless asked. **SCOPE included, with no exception**: report it, they decide.

### Discuss first, fix when the thread settles

Only a decision produces code.

- **Still open** (latest comment is a question or challenge) → reply with evidence, no edit, not even a partial one.
- **Unsure it's settled?** Propose the exact change and ask for a yes.
- **Settled** (`yes`, `do it`, `agreed`, or a directive) → fix per *their* direction where it differs from yours, then reply with `file:line` and what changed.
- **Reversal beats consistency.** If a finding was wrong, say so, drop it, revert any edit made for it.
- **Silence is consent for clear-cut blocking HIGH/MEDIUM bugs only.** Everything else waits for a directive; when in doubt it waits.

## Phase 4: Fix

Fix on the branch under review: read the source, make a **minimal, targeted** change, follow reviewer direction exactly. No refactors, renames, files outside the diff, or new dependencies. If unsure, leave it as an Open question.

**A finding with a `Repro:` gets it re-run after the fix**; quote red-then-green in the reply. Delete the scratch harness, or keep it as a real test. A repro still red means revert the edit and reopen the thread.

Land by the published rule:

**Unpushed head:**

```bash
git commit -a --amend --no-edit
gh stack rebase --upstack           # REQUIRED after any amend
```

If the branch isn't the tip, `gh stack down` / `gh stack switch` first, amend, then cascade.

**Published head:**

```bash
git commit -am "<what the round fixed>"
# no push. Phase 6 pushes, on the human's word.
```

Before `git add`, run the `fix` row of `../review-exchange/config.md` over the tree. Then `git status --short`; restore anything it reformatted that you didn't touch (`git checkout -- <path>`) and note the drift. Never use a formatter the repo hasn't configured.

Then **draft** one reply per thread you acted on, each to its own file under `$REVIEW_STATE/revise/<pr>/` (`reply-<thread>.json`, a `{"body": "..."}` object ready to `--input`). Nothing is posted in this phase.

**Several branches with actionable items — fan out over worktrees.** Map each comment to the commit that introduced the line (`git log -L` or `git blame`). Spawn one fix agent per branch, in parallel, each in its own worktree. Each agent's prompt:

---

**You are a code fix agent** in an isolated git worktree. Nothing you write may show up in the repo's `git status`.

```bash
wt=$REVIEW_STATE/revise/fix-<branch>
git worktree add "$wt" <branch>
cd "$wt"
pnpm install --prefer-offline   # config's `install`
```

**Issues to fix:** <file:line, category, what to change, reviewer direction verbatim>

**Conventions:** read `$SHARED_CONVENTIONS` and any per-directory convention file beside the files you touch.

1. Read the commit under review: `git show <branch>`.
2. Make a **minimal, targeted** fix per issue, following reviewer direction exactly. Where there is a `Repro:`, run it before (red) and after (green) and report both. Still red → revert and report unfixed.
3. No refactors, no files outside the commit's diff, no new dependencies.
4. Unsure → record under Open questions.
5. `git commit -a --amend --no-edit`. No new commit, no rebase, no push.
6. Report per fix: `file:line`, category, what changed; plus Open questions.
7. `cd` out, then `git worktree remove "$wt"`.

---

A branch checked out in the main checkout can't go in a worktree; the parent fixes that one directly.

**Read each agent's diff, not its report**: `git show <branch>`, confirm the edit is the one asked for with nothing riding along; re-run any claimed-green repro. An unconfirmable report is an unfixed finding.

**Cascade once, after every agent has finished** (serial; parallel rebases fight):

```bash
gh stack bottom && gh stack rebase --upstack
gh stack view
```

Pushing waits for Phase 6.

After fixing, reply in crit (interactive only) via a bulk `crit comment --json --file ... --author 'Claude Code'` with `reply_to` entries: `file:line` plus one line on what changed.

### Reply template (single-PR shape)

**review-exchange owns the reply shape and verdict badges**: badge line, AI;DR, evidence toggle, evidence line, which verdicts an ask accepts, the rung a `won't fix` needs, and that the author never resolves. Load it and `/ai-ethics` (marker). Do not restate or adapt it. This skill adds:

- **The evidence line carries the commit**: `37ad3509 · apps/api/profile/saveProfile.ts:162`.
- **A `fixed` re-runs the finding's repro**, same command, red then green.
- **Draft, don't post.** A reply whose wording is undecided is not drafted.
- **Body obligations have no root comment id**: one PR-level comment (`gh api repos/{owner}/{repo}/issues/<n>/comments -f body='...'`), drafted to its own file, one line per item. Skip if every body item was covered by a thread reply.

## Phase 5: Loop (autonomous: no relaunch, no third round — summarize, go to Phase 6)

1. Recompute `head`/`base`/`range`.
2. `crit stop` the current daemon, then relaunch with `--no-open` (`run_in_background: true`) with `CRIT_PORT` exported to the first launch's port. **Read the re-anchoring table in `crit-mechanics.md` first**: default is to relaunch on the **original** range and tell the reviewer the diff pane is pre-fix. Re-verify with `/api/file/comments?path=<file>` and confirm only one session for this cwd.
3. Tell the reviewer (same URL): fixes are in, replies are **drafted**, nothing is pushed or posted, open discussions remain; click **Finish Review** again.

Repeat Phases 3–5 as long as the reviewer keeps reviewing. **You do not decide when this ends**: a quiet round is not the end. It closes on "done" / "wrap up" or a publish instruction. Then summarize:

```
## Review Summary: <base>..<head>

### <short sha> — <first line of commit message>   (omit the heading for a single commit)
**Fixed:**
- [Category] file:line — description of fix
**Open questions (require human judgment):**
- [Category] file:line — question and why it needs human input
**Held, waiting on your word:**
- <sha> — committed locally, not pushed
- <n> thread replies drafted at <paths>, not posted
- <branch> — downstack/upstack behind, not yet aligned
```

Never report a round finished while something is still held; say what is held and what sends it.

**Unpushed head:** confirm `gh stack view` shows no branch needing a rebase; leave the daemon running.

**Published head:** name the local sha, which thread each drafted reply answers and with which verdict, the threads left as `needs your call`, and the body obligations with outcomes (deferred ones with their trigger). Every thread stays unresolved.

## Phase 6: Publish, on their word and not before

Only from an instruction that can only mean publish. Send what Phase 4 prepared; **author nothing new.**

1. **Re-read the drafts.** Re-check each against the tree (reversed thread, shifted `file:line`, stale sha) and fix the draft. **Then pull the work-list again** (Phase 0 step 4) and compare: any new thread, comment, review body, or new remote commit means stop, publish nothing, sort the new items into the round, and tell the human.
2. **Push**: plain `git push` on a published head, `gh stack rebase --upstack` first when an amend moved descendants. Rejected → `git fetch` and rebase your own commit; never `--force`.
3. **Post the replies**, one per thread, `--input` from its drafted file. On a fan-out, one push and one reply set per PR.
4. **Body obligations** in one PR-level comment, unless already covered.
5. **Verify what landed**: `git rev-parse HEAD` against the remote ref, and re-read the threads to confirm each reply sits where meant (not as a parallel thread).
6. **Check the stack after the push**: `gh stack view`. If any descendant branch is now behind the pushed head, rebase it onto the new head (`gh stack rebase --upstack`, per `commit-with-stack`), push it plainly, and report it. Never touch the parent's published shas; if the rebase conflicts, stop and report instead of guessing.
7. Report the published shas, reply URLs and stack state. Then `crit stop`, and remove the worktree if one was used.

Every thread stays **unresolved**; the reviewer resolves it.

## Mechanics

- **review-exchange skill** before the first finding and reply: badges, verdict table, ladder, cite rules, reply shape, marker, who resolves.
- **`../review-exchange/references/crit-mechanics.md`** before the first `crit` call: the single-session precondition, the `focus_key` trap, verification endpoints, authoring via `--file`, deleting a comment, pinning the port with `CRIT_PORT`, and the finish handshake.
- **`../review-exchange/references/github-review-api.md`** before the first `gh api` call against a PR's reviews: the thread query, REST/GraphQL id bridge, replies endpoint, outdated anchors.

Fix a gotcha in those files, not here.
