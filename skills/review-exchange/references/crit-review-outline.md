# Crit-driven review skills — shared outline

Two sibling Claude Code skills for code review, both built on the same idea:
a **hybrid, human-gated review-and-fix loop** where Claude surfaces findings as
[crit](https://github.com/inculca/crit) inline comments, a human curates and
directs in the browser, and Claude acts on the human's intent each round.

- **`revise`** — pre-push review of *local* changes. Fixes land as local
  commits. Never touches a remote.
- **`review-pr`** — review of a *GitHub PR*. Iterates on the **review itself**
  (never the code), then posts a cleaned-up set to GitHub on request.

> The installed skills are **git + `gh stack`**. Every VCS-specific step is still
> marked `«…»` below with the git command in place, so the outline stays portable —
> substitute another VCS there if you ever adapt it. The crit mechanics and the loop
> structure are the part worth copying.

---

## The shared philosophy

- **Claude proposes, the human disposes.** Claude never silently rewrites code or
  posts to GitHub. It authors findings; the human reads, replies, dismisses, or
  adds their own; a **Finish Review** click is the trigger for the next round.
- **Act on intent, not literal text.** Each round, classify *every* comment —
  Claude's findings, the human's replies, the human's own new comments — by what
  the human *wants*:
  - **Question / discussion** → investigate (read code, package types, conventions)
    and reply with concrete evidence. **No code change.**
  - **Acknowledgement / change request / human directive** → fix in that spirit,
    then reply noting what changed and where.
  - **Dismissed** ("ignore", "fine", "not an issue") → drop it.
- **Flag real issues only.** Read surrounding source before flagging — the "bug"
  may be handled elsewhere. No style nits, no theoretical concerns. When unsure,
  frame the finding as a *question*, not a claim.
- **One crit session for the whole loop.** Launch the daemon once, reuse the same
  port/URL every round. crit live-reloads its `review.json`, so headless edits
  appear in the open browser immediately — no restart, no new tab.

---

## `revise` — local pre-push review

**Phase 0 — Context & range.**
- `«resolve the range to review»` — git: `base=$(git merge-base develop HEAD)`, review
  `base..HEAD`. Commit or stash first: the range is commit-to-commit, and crit anchors
  comments to lines on disk.
- Gather review context once: convention docs (`docs/conventions/*.md`), any
  `BUGBOT.md` files from each changed file's directory up to the repo root.
  Store as `SHARED_CONVENTIONS` to hand to fix agents later.
- Review a concrete range, not a "PR mode" — it forces crit onto the plain git
  diff path and matches exactly what changed.

**Phase 1 — Launch the single crit session.**
- **Precondition: exactly one crit session for this working dir.** Stale daemons
  shadow yours and silently break comment visibility (see Gotchas).
- Launch `crit --range <base>..<head>` in the background; let it open the browser.
- Capture and **note the port** — reused for the whole loop. Relay the URL.

**Phase 2 — Review & author findings (live).**
- Read the changed *files*, not just the diff. Check: Logic/correctness, edge
  cases, security (OWASP-aware), convention violations, API/data (breaking
  changes, missing validation, N+1, missing indexes).
- Author **all** findings in one bulk `crit comment --json --file … --author …`
  call. Each body leads with severity (**Critical/Warning/Suggestion/Open
  Question**) + category tag, then what's wrong, why, and a concrete fix.
- **Verify the human can actually see them** (crit's own count is not enough — see
  Gotchas). Then wait for **Finish Review**.

**Phase 3 — Process the round by intent.** (the shared philosophy, applied)

**Phase 4 — Fix (adaptive).**
- *Single change:* fix directly — minimal, targeted, in the change under review.
  `«land the fix into the change being reviewed»` — git: `git commit -a --amend --no-edit`,
  then `gh stack rebase --upstack` (required; descendants are stale until it runs).
  No refactors, no new deps.
- *Multi-branch stack:* map each comment to the commit that introduced the line,
  then `«spawn a parallel fix agent per branch in an isolated workspace»` — git:
  `git worktree add worktrees/fix-<branch> <branch>`, the same isolation the repo's own
  execute command uses. Each agent gets the actionable comments + `SHARED_CONVENTIONS`,
  makes minimal fixes, amends its own branch, and records anything ambiguous as an Open
  Question. **Agents never rebase** — cascade once, serially, from the parent after they
  all finish, or parallel restacks fight over the same descendants.
- Reply on each fixed crit comment noting `file:line` and what changed.

**Phase 5 — Loop or finish.**
- Fixes moved the head (amend rewrites shas) → `«recompute the range»`, restart crit
  on the **same port** with `--no-open` (URL unchanged). Re-verify.
- Repeat 3–5 on each Finish Review until no actionable comments remain. End with a
  summary (Fixed / Open Questions). With amend-in-place there are no separate fix
  commits to fold in — `«confirm the stack is consistent»` (git: `gh stack view` reports
  nothing needing a rebase). Then `crit stop`.

---

## `review-pr` — GitHub PR review

Same loop, but it iterates on the **review document**, not the code, and ends by
posting to GitHub. Three human-gated phases: **Discuss** (default, loops) →
**Clean up** (only when asked) → **Submit** (only when asked). Never clean up or
submit unprompted.

**Phase 0 — Identify PR & gather context.**
- Resolve the PR number (arg, or `gh pr view`, or `«branch→gh pr list»` — git:
  `gh pr list --head $(git rev-parse --abbrev-ref HEAD)`).
- `«fetch so the local checkout matches the PR head»` — comments anchor to file
  lines *on disk*, so the checkout must match the head. Need both base and head
  commits present locally.
- Fetch in parallel: metadata, diff, existing review comments, reviews.
- **Compute a merge-base range, not "PR mode"** — `«mb = merge-base(base,head)»`
  (git: `git merge-base "$base" "$head"`), review `mb..head`. (PR mode does a tip-to-tip two-dot diff that folds in
  unrelated base-branch commits when the branch isn't cleanly rebased.)
- Separate human feedback from bot comments; group threaded replies; for each
  human comment **read the current file** (branch may have been force-pushed) and
  classify ADDRESSED / PARTIAL / NOT. Check adjacent PRs if it's a stack.

**Phase 1 — Launch the single crit session.** (same as revise)

**Phase 2 — Review & author comments (live).**
- Flag correctness/security/perf/consistency/design with **HIGH/MEDIUM/LOW**.
  Don't re-flag feedback humans already gave or explicitly deferred.
- Include one **review-level summary** comment (internal context; stripped before
  posting). Author in one bulk call; verify visibility; wait for Finish Review.

**Phase 3 — Discussion rounds (loop).**
- Process replies by intent (philosophy above). The human's *own* new comments are
  draft comments to the PR author — reply with supporting facts; don't
  rubber-stamp, show counter-evidence if a claim is wrong. Never `--resolve`.

**Phase 4 — Clean up (only when asked).** Transform `review.json` into a
post-ready set: remove dismissed/junk comments, finalize kept ones into
self-contained author-facing bodies, **strip all internal discussion** (replies +
the review-level summary), drop empty files. Print the final set for sign-off.

**Phase 5 — Submit (only when asked).**
- **Always `event: COMMENT`.** Never `REQUEST_CHANGES` or `APPROVE` — severity
  belongs in the comment bodies, not in a verdict that gates the author's branch.
- **Mark authorship**: prefix every Claude-drafted comment with a
  `_Drafted by Claude Code_` line (**no emoji**); leave the human's own comments
  unmarked (they post under the human's identity). When cleanup has folded Claude's
  analysis into a comment the human authored, that comment is Claude-drafted in
  substance — mark it, or ask.
- **Re-anchor file-scope comments first.** GitHub can't inline a whole-file
  comment; give each one a line range inside a diff hunk, or fold it into the
  review body. A payload with an out-of-diff line **422s the entire review** —
  nothing lands partially.
- Try `crit push --dry-run` first; **known failure (confirmed on 0.18.4)**: every
  comment on a `--pr`-mode review is classified `full-stack-only`, the plan reports
  `0 postable`, and the confirm command it prints (`crit push --pr <n>`) is invalid
  syntax — `push` takes a bare positional PR number. Fall back to the GitHub reviews
  API (`gh api repos/{owner}/{repo}/pulls/<n>/reviews --input <payload>`).
- Confirm the posted review's `html_url`, `user` and `state`, then re-read the PR's
  inline comments to verify each anchor. **On a 5xx, list the PR's reviews before
  retrying** — a failed POST can still have created one, and a blind retry
  double-posts. Then `crit stop`.

---

## crit gotchas worth carrying over (tool, not VCS)

These bit us repeatedly and are independent of which VCS you use.

**What `crit push` actually does** (verified on 0.18.4, by experiment):

- **It never summarizes.** Each surviving thread posts verbatim: the parent as an
  inline comment, then every reply as a threaded reply (`Posted N comments` /
  `Posted N replies`). This is exactly why Phase 4 strips internal discussion — skip
  that step and the whole Claude↔human transcript ships to the author.
- **Resolved threads are excluded** from the push plan. Resolving *is* the mechanism
  for "disregard this conversation"; there's no separate exclusion flag.
- **Review-level comments are not pushable** — the plan lists them as
  `Review-level (not pushable)`. The GitHub review body comes from
  `crit push --message` (or the API payload's `body`), never from a review-level
  crit comment.
- **There is no UI trigger for pushing.** The served bundle has no push/GitHub
  action at all — `crit push` is CLI-only.

- **The daemon live-reloads `review.json`** (0.16.x and still true on 0.18.4). Once a comment has the
  right `focus_key`, headless `crit comment` writes and raw `jq`/Python edits show
  up live — no stop→edit→relaunch dance.
- **Comments are filtered by `focus_key`, stamped only when the daemon is
  detected.** A `focus_key: null` comment is hidden from the browser even though
  `crit status` still counts it. Classic symptom: *status says N, browser shows
  0*. Cause is almost always **multiple crit sessions sharing this cwd** — find
  them (`grep -l "$(pwd)" ~/.crit/sessions/*.json`), kill stale PIDs, remove their
  session JSON so exactly one remains, then re-author. **Never hand-edit
  `focus_key`.**
- **Verify with the right endpoint.** Inline comments live at
  `/api/file/comments?path=<file>` — *not* `/api/comments` (returns `[]`) and
  *not* `/api/session` `comment_count` (reads 0 even when rendered). Review-level
  comments are in `/api/session` `review_comments`.
- **Never run `crit comment --help`** — `--help` becomes a comment body. Use
  `crit --help`.
- **No per-comment delete.** Edit `review.json` directly (path from `crit
  status`) with `jq`/Python — never string-edit it. Picked up live.
- **Keep the port stable.** Reuse the first launch's port for the whole loop; on
  every relaunch pass `--port <same-port> --no-open` so the open tab stays valid.
- **Quoting.** Bodies with apostrophes/backticks break shell quoting. Always
  author via `--file <json>` (write the JSON with a tool), never inline-quoted.
  In particular **never pipe JSON through `echo`** — zsh's builtin `echo` expands
  `\n` inside the string, turning escaped newlines into real ones and making crit
  reject the payload as `invalid character '\n' in string literal`.
- **The review file may live under a different session than the branch you're on.**
  `crit status` resolves the review by *branch*, so checking out the PR branch
  mid-review makes it look for a review file that doesn't exist (`review_file_exists:
  false`) while the daemon keeps serving the original. Target the session explicitly
  (`--session <id>`) rather than trusting cwd/branch resolution.
- **Writes into `~/.crit/` may be sandbox-blocked** for an agent even when the
  review is otherwise driveable. Posting to GitHub doesn't need them — only updating
  the human's browser view does, so don't let that block Phase 5.

---

## VCS-specific bits to re-implement (the `«…»` markers)

When adapting to your VCS, these are the only places that need real work:

1. **Range computation** — resolve "what to review" to a concrete `base..head`
   diff range (local change set; or PR merge-base..head). git: `git merge-base`.
2. **Landing a fix** — put a fix into the change/commit under review. git:
   `git commit --amend` + `gh stack rebase --upstack`.
3. **Parallel fix isolation** (multi-branch only) — give each fix agent an isolated
   working area so they don't collide, then cascade once from the parent. git:
   `git worktree add`. A branch already checked out in the main checkout can't be checked
   out in a worktree — the parent fixes that one directly.
4. **Keeping the checkout matched to the head** — comments anchor to lines on disk, so
   the working copy must match the commit/PR head being reviewed. git: `git fetch`, then
   compare `git rev-parse HEAD` against the PR's `headRefOid`.

Everything else — the crit session lifecycle, the human-gated loop, comment-by-
intent processing, the discuss→clean-up→submit gating — is reusable as-is.
