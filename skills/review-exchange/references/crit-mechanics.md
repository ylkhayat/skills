# crit CLI mechanics and gotchas

Shared reference for the crit-driven review skills (`review-pr`, `revise`). Read this before
the first `crit` call in a session. Verified against crit 0.16.x–0.18.4.

Both skills are user-invoked (`disable-model-invocation: true`), so neither can invoke the other —
this file is the single source of truth they both point at.

**Maintaining it.** New or corrected crit behaviour goes *here*, never back into a skill: these ~50
lines were duplicated across both SKILL.md files and had already drifted, so a one-gotcha fix was a
three-file edit. A skill gets only what is a **step** in its own flow (launch the daemon, verify the
comments landed) or a decision that skill owns — never the explanation behind it. The third copy, in
`crit-review-outline.md`, is a deliberately self-contained write-up for sharing: leave it alone.

## One session per working directory (precondition)

`crit comment` decides which daemon to write *through* by matching the current cwd against
`~/.crit/sessions/*.json`. A stale daemon from an earlier review in the same cwd shadows yours, makes
`crit comment` mis-resolve, and silently breaks comment visibility (see `focus_key` below). Before
launching:

```bash
grep -l "$(pwd)" ~/.crit/sessions/*.json
```

Any match: `crit stop` / `kill` those PIDs and `rm` their session JSON so exactly one remains.

Reviewing in a per-review worktree gives each review its own cwd, which keeps this honest for free.

## focus_key: why comments vanish

Every comment is stamped with `focus_key` (`range:<base>..<head>`), `head_sha` and `diff_scope`, and
the daemon **only serves comments whose `focus_key` matches the session focus**. `--range` sessions
filter too.

`crit comment` writes that stamp by going *through* the running daemon. If it cannot resolve the
daemon it prints `Note: ... no daemon running; head_sha unknown` and writes `focus_key: null` — and
null-keyed comments are **hidden from the browser** while `crit status` still counts them.

**On 0.23.0 it also happens silently with exactly one session for the cwd**: bare `crit comment`
printed `Added N comments`, no `Note:`, and wrote `focus_key: null` anyway. Passing
`--session <id>` stamped the range key. Pass `--session` on every `crit comment`, and check
`review.json` for null keys after each call rather than trusting the absence of the Note.

The classic symptom is `crit status` says N, the browser shows 0. That is **not** "you launched with
`--pr`" — it is a null `focus_key`, almost always from multiple sessions sharing the cwd. A restart
does not fix it. Never hand-edit `focus_key`: guarantee the single-session precondition above, then
re-author.

## Authoring

- **`crit comment` only ever appends — `crit.sh author` is what makes re-authoring safe.** Posting the
  same round twice shows the reviewer every finding twice, and my notes warning about it did not stop
  it happening, which is why the fix is in the script rather than in discipline.
  `../review-pr/scripts/prune_authored.py` drops our own previous comments just before the new batch lands, and
  spares two kinds absolutely: **a comment the reviewer replied to** (deleting it would orphan what
  they wrote) and **a comment by anyone else**. It renders first and prunes second, so an invalid
  `findings.json` cannot throw away good comments to then post nothing, and it saves the previous file
  to `review.json.prev`. Re-author freely — after a re-badge, after folding in a discussion, after a
  typo. Calling raw `crit comment` yourself skips all of this.
- **Always `--file <json>`, never inline bodies.** Apostrophes and backticks break shell quoting
  (`'\''` leaks literally into the file). Write the JSON with a file write, then
  `crit comment --json --file <path> --author 'Claude Code'`.
- **Never pipe JSON through `echo`.** zsh's builtin `echo` expands `\n` inside the string, so escaped
  newlines become real ones and crit rejects the payload with
  `invalid character '\n' in string literal`.
- **One bulk call**, not one call per comment. Entries: `{"file": "<path>", "line": 42, "body": "..."}`,
  `"line": "23-25"` for a range, `reply_to` for a thread reply; omit `file` for a review-level entry.
- **Line numbers are 1-indexed against the file on disk**, not diff positions.
- **Never run `crit comment --help`** — `--help` becomes a comment body. Use `crit --help` only.

## Verifying (the count crit reports is not enough)

- **Inline comments and replies**: `curl -s "localhost:<port>/api/file/comments?path=<file>"` — the
  endpoint the diff view actually fetches. Its length must match what you authored for that file.
- **Review-level comments**: `/api/session` → top-level `review_comments`.
- **Every comment in `review.json`** (path from `crit status`) must have a **non-null `focus_key`**.

Do not trust `/api/comments` (returns `[]`) or `/api/session`'s per-file `comment_count` (reads 0 even
when comments render correctly).

## Live reload, restarts, ports

- **The daemon live-reloads `review.json`.** Once a comment carries a valid `focus_key`, `crit comment`
  writes and raw jq/Python edits appear in the open browser immediately. No stop→edit→relaunch dance.
- **Except the review-level comment, which is served from memory.** A hand-edit to `review_comments[]`
  in `review.json` lands on disk and is *not* picked up: `/api/session` keeps serving the pre-edit body
  indefinitely. Confirmed 0.18.4. Re-read the file to prove the edit took, then restart to serve it.
  Authoring a *new* review-level comment through `crit comment` is fine — only raw edits to an existing
  one are affected.
- **Restart only when** the daemon died (`curl /api/session` fails, or `crit status` reports
  "Daemon: not running"), the head moved (new commits, or an amend) and the diff needs re-anchoring, or
  you hand-edited the review-level comment.
- **On restart**: relaunch with **`--range <base>..<head>` and NO `--session`**, from the review's own
  cwd, then `--no-open`. Re-verify with `/api/file/comments?path=<file>` **and** that
  `/api/session` reports `focus.kind == "range"`.

  **`--session` forces `focus: {kind: "working_tree"}`** — not only after the head moves (the table
  below), but on *every* restart, including one where nothing has changed at all. Every range-keyed
  comment is then filtered out and the browser shows an empty review while `review.json` still holds
  everything with valid non-null `focus_key`s. `--range` alone resolves to the same session by cwd, so
  dropping `--session` costs nothing and is the only form that comes back with a range focus.
- **`crit stop` can flush stale in-memory state over a hand-edit.** After editing `review.json`
  directly, `kill -9` the daemon instead, then re-read the file to confirm the edit survived before
  relaunching.
- **Killing it takes more than the PID in the startup line.** A session runs `crit _serve
  --session-key <id>` alongside the `crit --range ...` parent, and both hold the port — `lsof -ti
  :<port>` can also return an unrelated client. `pkill -9 -f "crit _serve"` plus `pkill -9 -f "^crit
  --"`, then confirm the port is free, is what actually clears it. A launch that prints **"Connected to
  crit daemon"** rather than "Started"/"Restarted" means a daemon survived and your flags were ignored.
- **Never set `CRIT_PORT` on `crit comment` (0.23.0).** Only the launch needs it. With it in the
  environment, `crit comment` skips the daemon silently: it prints `Added N comments` with no
  `Note: ... no daemon running`, and writes entries with no `focus_key`/`head_sha`, which the browser
  hides. Seen 2026-10-20; `env -u CRIT_PORT crit comment ...` stamped correctly.
- **Pin the port with `CRIT_PORT`, not `--port`.** The flag works on a fresh launch but is dropped on
  reconnect: `daemonArgsForReconnect` rebuilds the `_serve` argv from `cli_args` plus host/public-url
  and never re-adds the port, so a restart lands on a fresh random one (51710 → 52205 → 52288 across
  two restarts). The daemon child does inherit the launcher's environment, and port resolution is
  `--port` → `CRIT_PORT` → config `port` → random — so `CRIT_PORT=<n>` in the environment of every
  crit call survives a restart, a reconnect, and a killed daemon. Verified on 0.18.4: killed a daemon
  on 43262, relaunched, came back on 43262. That is what keeps the reviewer's open tab alive, so
  **pin it per review** (`/review-pr` derives it from the PR number) rather than relaying a new URL.
  A global default can go in `~/.crit.config.json` `port`, but a fixed global port collides between
  two concurrent reviews.

### Re-anchoring after the head moves: you cannot keep both the thread and the new diff

A comment's `focus_key` is `range:<base>..<head>`. Once you commit, that key names the *old* head, and
the three obvious moves all fail differently:

| What you run | What happens |
|---|---|
| `crit --range <base>..<newhead> --session <id>` | session restarts with `focus: {kind: "working_tree"}` — **not** a range focus. Every range-keyed comment is filtered out: `/api/file/comments` returns 0 for every file while `review.json` still holds them with valid non-null `focus_key`s. |
| `crit --range <base>..<newhead>` (no `--session`) | a **new session id and an empty review file**. It does not re-key the existing thread onto the new head. |
| `crit --range <base>..<oldhead>` | resolves back to the original session, serves all comments and replies — but the diff pane shows the pre-fix code. |

So it is a choice, not a procedure. **Prefer the third**: relaunch on the *original* range so the round's
conversation stays readable, and say plainly that the diff pane is pre-fix and `git show <sha>` is the
real one. The replies carry the new `file:line`s anyway, and a visible thread with a stale diff beats a
fresh diff with no thread.

Do not hand-edit `focus_key` to bridge this. The keys are valid; only the session focus disagrees.
- **Keep the port stable for the whole loop.** Stale daemons from other reviews keep their old ports.

## The finish handshake, and how the reviewer gets stuck

The reviewer's **Finish Review** button is not a fire-and-forget POST. `POST /api/finish` flushes the
review file, then:

- **Zero unresolved comments** → `approved: true`, and the daemon records stats and **shuts down**. The
  port is released; there is nothing left to reconnect to.
- **Any unresolved comment** → `approved: false` and the session is marked *waiting for agent*. The
  browser drops into a modal reading **"Waiting for your agent to finish..."**, and the reviewer cannot
  start another round while it is up.

What clears that modal, in a `--range` session, is exactly one thing: **another
`POST /api/review-cycle`**. That handler calls `SignalRoundComplete` (the review round increments,
the browser refreshes) and then blocks until the next finish.

- **`/api/round-complete` does not work here** — it returns **409 `round-complete is not meaningful in
  range mode`**, and every `/review-pr` session is a range session.
- **The blocking client is what a round's completion signal actually is.** `crit --range` POSTs
  review-cycle and blocks; the reviewer's click is the HTTP response, and the client then exits. A bare
  `curl -X POST localhost:<port>/api/review-cycle` is an equivalent client and the cheaper one for a
  later round — no new session, no second browser tab, no port change.
- **So re-enter the cycle as soon as you have read a round, before you start working.** The release and
  the arming are the same call: the reviewer gets their browser back while you author, and the next
  click already has a listener.
- **The first entry on a fresh session does not signal round-complete** (`awaitingFirstReview`), which
  is correct — there is nothing to release yet.

### The click survives a dead listener: the finish hook

Because the signal is an HTTP response to a process, a reaped background task loses it. crit's command
hooks close that hole: a **global** hook at `~/.crit/hooks/on_finish_unresolved.sh` (and
`on_finish_approved.sh`) runs synchronously on every finish with `CRIT_SESSION_KEY`, `CRIT_APPROVED`,
`CRIT_UNRESOLVED_COUNT` and `CRIT_MODE` in its environment. Global hooks skip the project trust gate,
are capped at 60s, and a failure never blocks finish.

The installed pair appends one line per finish to `~/.crit/finish/<session-key>.log`, which makes the
reviewer's click durable state on disk rather than a message to a process that may be gone. Compare the
line count against what you last saw to detect a round you missed. Only one hook fires per finish, most
specific first, and a **project** hook (`.crit.config.json` `hooks`, or `.crit/hooks/*.sh`) outranks the
global one — so a repo that defines its own finish hook silently replaces this signal.

## Deleting

**There is no per-comment delete.** Edit `review.json` directly (path from `crit status`) with jq or
Python — never string-edit the JSON. The daemon picks the edit up live.

## `crit status` resolves by branch, not by session

If the checkout moves mid-review it reports a different `review_file` with `review_file_exists: false`
while the daemon keeps happily serving the original. Pass `--session <id>` explicitly to every headless
command rather than trusting cwd/branch resolution — and don't conclude the review is gone.

The review file under `~/.crit/reviews/<id>/` outlives the worktree it was created in, so thread history
survives cleanup — but a later round in a *new* worktree can no longer resolve it by cwd or branch.
`--session <id>` from then on.

**`crit stop` ignores `--session` (0.18.4).** It resolves by branch regardless, so
`crit stop --session cd26a39ba079` died with `no session found: .../dd7cd4b8f9c5.json` — a session id
that was never passed to it. Run a bare `crit stop` from the review's own cwd instead, and fall back to
`kill <pid>` (the PID is in the `Started crit daemon` line) if the branch has moved out from under it.
`crit comment --session <id>` is unaffected — that one honours the flag.

## `crit push` is broken for review submission (confirmed on 0.18.4)

Every comment on a `--pr`-mode review is classified `full-stack-only`, so the plan reads `0 postable`
and pushing accomplishes nothing but the `--message`. It does not budge with `--scope layer`, nor by
checking out the PR branch, and the confirm command it prints — `crit push --pr <n>` — is invalid
syntax (`push` takes a bare positional PR number and rejects `--pr`). Post via
`gh api repos/{owner}/{repo}/pulls/<n>/reviews --input <file>` instead.

## Sandbox-blocked writes

Writes into `~/.crit/` can be sandbox-blocked even when everything else works. That blocks only the
live browser update, never a GitHub submit (whose payload is built from data already in hand). If
blocked, print the final set in the conversation for sign-off, offer a one-line `cp` if the reviewer
wants the browser updated, and carry on.
