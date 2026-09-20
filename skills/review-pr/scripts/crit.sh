#!/usr/bin/env bash
# crit lifecycle for /review-pr. Run from the review worktree.
#
#   crit.sh port <pr>              the pinned port for this review (deterministic)
#   crit.sh launch                 start (or reclaim) the daemon on that port; prints the URL
#   crit.sh author <findings.json> render + one bulk crit comment call, then verify
#   crit.sh verify                 the triad: per-file counts, review-level, focus_key
#   crit.sh wait                   release the reviewer's browser and block until the next Finish
#   crit.sh finished [since]       read the durable finish log (works with no daemon, no shell)
#
# Reads <state root>/review-pr/pr-<n>/crit.env (written by pr-context.sh) for
# CRIT_PORT and CRIT_RANGE. Nothing is ever written inside the checkout.
# Mechanics and the reasons behind every check: ../review-exchange/references/crit-mechanics.md
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Same dir pr-context.sh wrote, derived from the worktree name (review-pr-<n>).
# Run from the review worktree, or set REVIEW_DIR.
state_root="${REVIEW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}/review-pr"
review_dir="${REVIEW_DIR:-$state_root/pr-${PWD##*review-pr-}}"
mkdir -p "$review_dir"
env_file="$review_dir/crit.env"

# ---------------------------------------------------------------- port

# Deterministic per PR, so the reviewer's tab survives every restart. crit picks a
# random port by default and does NOT carry --port through a reconnect, but the
# daemon child inherits the environment — so CRIT_PORT is what actually pins it.
# Band sits below macOS's ephemeral range (49152+) to avoid a random collision.
port_for() {
  local base=$((40000 + ${1:-0} % 4000)) p
  for i in 0 1 2 3 4; do
    p=$((base + i))
    # Our own live daemon already holding it is a reuse, not a collision.
    [[ $(session_port) == "$p" ]] && { echo "$p"; return; }
    (exec 3<>/dev/tcp/127.0.0.1/"$p") 2>/dev/null || { echo "$p"; return; }
  done
  echo "crit.sh: no free port near $base" >&2; return 1
}

# The port of the session whose cwd is THIS worktree. Never "the last session
# file": an unrelated crit (a plan review in the repo root) answers on its own.
session_port() {
  jq -r --arg cwd "$PWD" 'select(.cwd == $cwd) | .port' "$HOME"/.crit/sessions/*.json 2>/dev/null | tail -1
}

# The review file of that same session, by the same cwd rule and for the same reason.
session_review() {
  local d
  d=$(jq -r --arg cwd "$PWD" 'select(.cwd == $cwd) | .review_path' "$HOME"/.crit/sessions/*.json 2>/dev/null | tail -1)
  [[ -n $d ]] && echo "$d/review.json"
}

load_env() {
  # shellcheck source=/dev/null
  [[ -f $env_file ]] && . "$env_file"
  : "${CRIT_PORT:=$(session_port)}"
  [[ -n ${CRIT_PORT:-} && $CRIT_PORT != null ]] || {
    echo "crit.sh: no port — run pr-context.sh, or pass one in $env_file" >&2; exit 1; }
  export CRIT_PORT
}

alive() { curl -s -m 2 -o /dev/null "localhost:$CRIT_PORT/api/session"; }

review_file() { crit status 2>/dev/null | grep -oE '/[^ ]*review\.json' | head -1; }

# Never depends on a live daemon: `launch` records the key in crit.env, because the
# one caller that matters (`finished`) runs precisely when the daemon is gone.
session_key() {
  [[ -n ${CRIT_SESSION:-} ]] && { echo "$CRIT_SESSION"; return; }
  local k
  k=$(curl -s -m 2 "localhost:$CRIT_PORT/api/session" 2>/dev/null | jq -r '.session_key // empty' 2>/dev/null || true)
  [[ -n $k ]] && { echo "$k"; return; }
  local rf; rf=$(review_file)
  [[ -n $rf ]] && basename "$(dirname "$rf")"
}

remember_session() {
  local k; k=$(curl -s -m 2 "localhost:$CRIT_PORT/api/session" | jq -r '.session_key // empty')
  [[ -n $k ]] || return 0
  grep -q "^CRIT_SESSION=" "$env_file" 2>/dev/null \
    && sed -i '' "s|^CRIT_SESSION=.*|CRIT_SESSION=$k|" "$env_file" \
    || echo "CRIT_SESSION=$k" >> "$env_file"
}

# ---------------------------------------------------------------- launch

launch() {
  load_env
  if alive; then
    remember_session
    echo "crit is already up at http://localhost:$CRIT_PORT — same URL, nothing to restart"
    return
  fi
  [[ -n ${CRIT_RANGE:-} ]] || { echo "crit.sh: no CRIT_RANGE in $env_file" >&2; exit 1; }
  # Relaunch on the ORIGINAL range: re-keying onto a new head hides the round's
  # whole thread (see the re-anchoring table in crit-mechanics.md).
  local open=(); [[ ${1:-} == --no-open ]] && open=(--no-open)
  crit --range "$CRIT_RANGE" ${open[@]+"${open[@]}"} >"$review_dir/crit.log" 2>&1 &
  for _ in 1 2 3 4 5 6 7 8 9 10; do alive && break; sleep 1; done
  alive || { echo "crit.sh: daemon did not come up; see $review_dir/crit.log" >&2; exit 1; }
  remember_session
  echo "crit is at http://localhost:$CRIT_PORT (port pinned — it stays this across restarts)"
}

# ---------------------------------------------------------------- verify

# Compare what review.json holds against what the browser is actually served.
#
# review.json's `files` is an OBJECT keyed by path ({"svc.ts": {comments, ...}}),
# not an array — an earlier version matched on a `file` key that does not exist
# there, so the loop iterated zero times and verify reported green while checking
# nothing. Counts are parsed strictly for the same reason: an unreadable review
# file must fail loudly, not compare against an empty string.
verify() {
  load_env
  local rf fail=0 nulls want_review served_review
  rf=$(review_file)
  [[ -n $rf && -f $rf ]] || { echo "crit.sh: review.json not found via crit status" >&2; exit 1; }
  jq -e . "$rf" >/dev/null 2>&1 || { echo "FAIL  $rf is not valid JSON" >&2; return 1; }

  # A null focus_key means the comment is counted but invisible in the browser.
  nulls=$(jq '[.. | objects | select(has("focus_key")) | select(.focus_key == null)] | length' "$rf")
  if [[ $nulls -gt 0 ]]; then
    echo "FAIL  $nulls comment(s) with focus_key: null — invisible in the browser." >&2
    echo "      Cause is daemon resolution, not a stale render. Clear every session for this cwd" >&2
    echo "      and re-author; a restart does NOT fix it. Never hand-edit focus_key." >&2
    fail=1
  fi

  num() { [[ $1 =~ ^[0-9]+$ ]] || { echo "FAIL  unreadable count from $2" >&2; return 1; }; }

  # The daemon reloads review.json asynchronously and serves the review-level
  # comment from memory, so let it settle before calling anything short.
  local p want got settled=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    settled=1
    while read -r p; do
      [[ -n $p ]] || continue
      want=$(jq --arg p "$p" '.files[$p].comments | length' "$rf")
      got=$(curl -s "localhost:$CRIT_PORT/api/file/comments?path=$p" | jq 'length' 2>/dev/null || echo x)
      num "$want" "review.json ($p)" || return 1
      { num "$got" "the daemon ($p)" && [[ $got -ge $want ]]; } || settled=0
    done < <(jq -r '.files | keys[]?' "$rf")
    want_review=$(jq '.review_comments | length' "$rf")
    served_review=$(curl -s "localhost:$CRIT_PORT/api/session" | jq '.review_comments | length' 2>/dev/null || echo x)
    num "$want_review" "review.json (review-level)" || return 1
    { num "$served_review" "the daemon (review-level)" && [[ $served_review -ge $want_review ]]; } || settled=0
    [[ $settled -eq 1 ]] && break
    sleep 0.5
  done

  while read -r p; do
    [[ -n $p ]] || continue
    want=$(jq --arg p "$p" '.files[$p].comments | length' "$rf")
    got=$(curl -s "localhost:$CRIT_PORT/api/file/comments?path=$p" | jq 'length' 2>/dev/null || echo 0)
    if [[ $got -ge $want ]]; then printf 'ok    %s: %s served / %s\n' "$p" "$got" "$want"
    else printf 'FAIL  %s: %s served / %s — the reviewer cannot see them all\n' "$p" "$got" "$want" >&2; fail=1; fi
  done < <(jq -r '.files | keys[]?' "$rf")

  if [[ $served_review -ge 1 && $served_review -ge $want_review ]]; then
    echo "ok    review-level: $served_review served / $want_review"
  else
    echo "FAIL  review-level: $served_review served / $want_review — the review body is missing" >&2; fail=1
  fi

  [[ $fail -eq 0 ]] && echo "VERIFIED  http://localhost:$CRIT_PORT"
  return $fail
}

# ---------------------------------------------------------------- wait

# Two jobs in one call, and the order is the point:
#
#  1. RELEASE. A finish with open comments leaves the session waiting for an agent
#     and the reviewer stuck in "Waiting for your agent to finish...". In range mode
#     /api/round-complete refuses (409), so the ONLY thing that clears it is another
#     /api/review-cycle — which is exactly what this call is. Run it as soon as you
#     have read a round, before you start authoring, so the reviewer gets their
#     browser back while you work.
#  2. ARM. The same call then blocks until the next Finish Review and returns its
#     payload. Run it with run_in_background: true.
#
# If this process dies, the click is NOT lost: the global finish hook records it —
# see `crit.sh finished`.
wait_round() {
  load_env
  alive || { echo "crit.sh: daemon is down — 'crit.sh launch' first (same port)" >&2; exit 1; }
  [[ -x $HOME/.crit/hooks/on_finish_unresolved.sh ]] || \
    echo "crit.sh: warning: no ~/.crit/hooks/on_finish_unresolved.sh — a finish is only" >&2
  echo "armed on http://localhost:$CRIT_PORT — browser released, waiting for Finish Review"
  local out; out=$(curl -s -X POST "localhost:$CRIT_PORT/api/review-cycle")
  jq -r '"finish: approved=\(.approved) unresolved=\(.comments|length)"' <<<"$out" 2>/dev/null \
    || echo "review cycle returned: $out"
}

# The durable signal: one line per finish, written by the global crit hook, so a
# reaped background task never loses the reviewer's click.
finished() {
  load_env
  local key log n
  key=$(session_key)
  [[ -n $key ]] || { echo "crit.sh: cannot resolve the session key — no CRIT_SESSION in $env_file" >&2; return 1; }
  log="$HOME/.crit/finish/$key.log"
  [[ -f $log ]] || { echo "0 finishes recorded for $key"; return; }
  n=$(wc -l <"$log" | tr -d ' ')
  echo "$n finishes recorded for $key${1:+ (you last saw $1)}"
  tail -1 "$log"
  [[ -n ${1:-} && $n -gt $1 ]] && echo "NEW ROUND — read review.json and re-arm with 'crit.sh wait'"
  return 0
}

case ${1:-} in
  port)   port_for "${2:?crit.sh port <pr-number>}" ;;
  launch) launch "${2:-}" ;;
  author)
    load_env
    [[ -n ${2:-} ]] || { echo "crit.sh author <findings.json>" >&2; exit 1; }
    payload=$(mktemp -t crit-payload).json; : >"$payload"
    # Render BEFORE pruning: render.py dies on an invalid findings.json, and a prune
    # that ran first would have thrown away the good comments to post nothing.
    python3 "$here/render.py" crit "$2" > "$payload"
    # `crit comment` only appends, so re-authoring a round would show every finding
    # twice. Drop our own previous comments first — never one the reviewer replied to,
    # never anyone else's. Keeps a re-author (re-badge, fold in a reply, fix a typo)
    # the safe default it reads as.
    rp=$(session_review)
    [[ -n $rp && -f $rp ]] && python3 "$here/prune_authored.py" "$rp"
    crit comment --json --file "$payload" --author 'Claude Code'
    verify
    ;;
  verify)   verify ;;
  wait)     wait_round ;;
  finished) finished "${2:-}" ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac
