# GitHub review API mechanics

Shared reference for the review skills that touch GitHub: `review-pr` (posts and resolves as the
reviewer) and `revise` (replies and pushes as the author). Read it before the first `gh api` call
against a PR's reviews.

Mechanics only. **Policy lives in the skills** — whether to resolve a thread, what a reply may say,
what commit strategy is allowed — and the two skills deliberately differ. Fix a fact here; leave the
decision there.

## Reading the threads

```bash
gh api graphql -F o=OWNER -F r=REPO -F n=NUMBER -f query='
query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){
  headRefName baseRefName baseRefOid headRefOid
  reviewThreads(first:100){nodes{
    id isResolved isOutdated path line originalLine originalStartLine
    viewerCanReply viewerCanResolve
    comments(first:50){nodes{fullDatabaseId author{login} body url}}}}
  reviews(last:20){nodes{fullDatabaseId author{login} state submittedAt body}}
  comments(last:30){nodes{fullDatabaseId author{login} createdAt body}}}}}'
```

- **`fullDatabaseId` is the bridge to REST.** GraphQL thread ids (`PRRT_…`) and REST comment ids
  (`3820133926`) are different namespaces; the comment's `fullDatabaseId` is the REST id. The **first**
  comment in a thread is its root, and its REST id is what a reply posts to.
- **An outdated thread has `line: null`.** Its anchor moved with the head. Place it with `originalLine`
  / `originalStartLine`, and treat `isOutdated: true` as notice that the `path:line` cites *inside*
  those bodies are stale and need re-checking before anyone quotes them.
- **The review body and PR-level comments carry obligations too**, with no thread and therefore nothing
  marking them undone. Read every non-empty `reviews.nodes[].body` and `comments.nodes[].body`, not
  just the threads.

## Posting a review (as the reviewer)

`POST /repos/{owner}/{repo}/pulls/{n}/reviews` with `{event, body, comments:[…]}`. `event` is
`APPROVE` or `COMMENT`; omit it for a pending draft.

- **A comment anchor outside the diff 422s the whole review** — nothing lands partially. A multi-line
  anchor must sit inside one hunk: `{"path", "start_line", "line", "side": "RIGHT", "start_side": "RIGHT"}`.
  GitHub cannot inline a file-scope comment at all; give it a real line range or fold it into the body.
- **On a 5xx, list the reviews before retrying.** A failed POST can still have created the review, and
  a blind retry double-posts. `gh api repos/{owner}/{repo}/pulls/{n}/reviews` returning `[]` is the
  all-clear.

## Editing a posted review body

`PUT /repos/{owner}/{repo}/pulls/{n}/reviews/{review_id}` with `body`. Edits the review summary in
place, so a PR carries one summary that stays current instead of a stack of them. Needs the `id` from
the POST response (or from the reviews list).

## Replying in a thread

`POST /repos/{owner}/{repo}/pulls/{n}/comments/{root_comment_id}/replies` with `body`.

A fresh `pulls/{n}/reviews` POST on the same line opens a **parallel thread** and splits the
conversation — that is the failure mode this endpoint exists to avoid. Reserve a new review POST for
genuinely new findings.

## Resolving a thread

```bash
gh api graphql -f query='mutation{resolveReviewThread(input:{threadId:"PRRT_…"}){thread{isResolved}}}'
```

One call per thread, checking `isResolved` in the response. `unresolveReviewThread` is the inverse.

- **Read `isResolved` before `viewerCanResolve`.** An already-resolved thread reports
  `viewerCanResolve: false`, so treating that flag as permission alone makes every settled thread look
  blocked. Only a `false` on an *unresolved* thread is a real permission wall.
- Resolving is visible as who resolved it, so it is a claim that the thread is closed — verify the code
  at that line first.

## Whose account this posts under

Everything goes out under the `gh` token's account, which is a person. Anything Claude drafted carries
the `/ai-ethics` marker for that reason — load that skill and follow it. It owns the marker; nothing
here describes it.
