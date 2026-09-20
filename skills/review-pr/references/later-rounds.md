# Later rounds on the same PR

The reply shape and the resolve etiquette are in the **review-exchange** skill; this file is the round.

A PR that already carries a posted review is not a fresh review. **This phase subtracts:** a thread that
has landed gets resolved, not congratulated, and the body is edited rather than reposted.

## What is pre-authorized, and what is not

| | |
|---|---|
| **Resolving a verified fix** | **Pre-authorized.** Do it, then report it. |
| A reply, a body `PUT`, a new finding on new commits | Gated. Present it, wait for the sentence. |

"Verified" has teeth: read the current file at that line, and where the finding carried a `repro`,
re-run it and expect green. **A resolve without that verification is not pre-authorized** — a resolve is
a public claim that the thread is closed, and an unresolve does not un-notify anyone.

## The round

1. **Verify, offline — in parallel at four threads or more.** Reading the current file at N locations
   and re-running N repros is N independent jobs, so dispatch **one `haiku` agent per claimed fix in one
   message** (`references/fan-out.md`), each returning
   `{thread_id, landed, evidence, repro_result}`. Below four, do it yourself; the briefing costs more
   than the read. Either way run typecheck and lint once at the top and chase any external claim to
   groundtruth yourself. Then update `status` on each record in the state file
   (`$REVIEW_STATE/review-pr/<owner>-<repo>-<n>.json`) and draft every reply into a file.

   **The resolve is still yours.** An agent's word is not the verification the pre-authorization rests
   on — a `landed: true` with no evidence line, or a repro you have not seen go green, is an unverified
   thread and stays open.
2. **Resolve what landed** — `gh-review.sh resolve <state.json> <thread-id>…`, one call per thread,
   checking `isResolved` in each response.
3. **Launch crit and relay the URL** — `crit.sh launch` comes back on the same port as round 1, then
   `crit.sh wait` (background) to release the browser and arm the round. Every round, even one where all
   you have is "nine landed, one didn't". The reviewer reads the code themselves.
4. **Present the rest in the conversation**: per thread, what the author did, whether you verified it,
   and what you propose. Print the reply bodies in full and the refreshed body in full
   (`gh-review.sh render body <state.json>`).
5. **Wait for the go-ahead**, then `gh-review.sh reply` / `refresh`. Partial go-aheads are normal —
   "reply but hold the body". Do exactly what they name and nothing adjacent.

A round that ends at step 5 with only resolves posted is a **complete, successful round**. The
deliverable is the verified assessment, not the mutation.

## The action table

Read each thread against the current head and act **once**, off the ask badge it carries:

| What the author did | Reply | Resolve |
|---|---|---|
| Fixed it as asked | no | **yes, unprompted** |
| Fixed it differently, and it works | one line naming what they did instead | **yes, unprompted** |
| Didn't take a `non-blocking` | no | **yes, unprompted** |
| Answered a `question` | one line accepting the answer | **yes, unprompted** |
| Fixed it and it's still broken | one line, with the new `path:line` | no |
| Disagreed with you | no — the position is theirs to close | no |
| Asked you something | answer it, with evidence | no |
| Nothing yet, `blocking` still open | no | no |
| — it's another human's thread | never | never |

- **The resolve is the acknowledgement** — see "Who resolves" in the **review-exchange** skill. That is why
  the resolve needs no permission here and the reply does.
- **Skip resolved threads, and don't misread `viewerCanResolve`** — an already-resolved thread reports
  it as `false`, so only a `false` on an *unresolved* thread is a real permission wall, and that gets
  said in the conversation rather than worked around.
- **Replies thread onto the existing comment.** `gh-review.sh reply` uses the replies endpoint; a fresh
  review POST would start a second thread on the same line and split the conversation. Reserve a new
  review POST for genuinely new findings on new commits.
- **Refresh the body, don't repost it.** `gh-review.sh refresh` `PUT`s in place and saves the previous
  body to a file first, so the edit is reversible. The `round` field increments, the glyphs and counts
  follow `status`, and the AI;DR's last sentence gets rewritten to the new state of play. **Carry
  `reviewer_note` through untouched** — it stays until they hand you a different one.
- **Re-verify every `path:line` you quote when the head moved.** Recompute the range from the new
  `headRefOid`; GitHub keeps outdated comments but the cites *inside* them are stale, and `isOutdated`
  tells you which threads to distrust.
- **Nothing new to say and nothing to close is a valid round.** Launch crit anyway, hand over the URL,
  say so, and post nothing.

State and thread ids: prefer the state file, which already holds `review_id`, `comment_id` and
`thread_url` per finding from the submit. Refresh the live view with the `reviewThreads` query in
`../review-exchange/references/github-review-api.md` when the head has moved — `fullDatabaseId` is the bridge from a
GraphQL thread id back to the REST comment id. `crit pull <n>` fetches the posted comments into the
review file so they render inline. Read your own posted comments as your prior round, not as new human
feedback — do not re-raise what they already settled.
