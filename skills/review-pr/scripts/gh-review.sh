#!/usr/bin/env bash
# The GitHub half of /review-pr. Every network write to the PR goes through here.
#
#   gh-review.sh render body|crit|payload|event <findings.json>
#   gh-review.sh submit  <findings.json> [--dry-run]     POST review, read back, PUT body with links
#   gh-review.sh resolve <findings.json> <thread-id>...  resolve one thread per call
#   gh-review.sh reply   <findings.json> <root-comment-id> <body-file>
#   gh-review.sh refresh <findings.json>                 PUT the body in place (round/ledger/counts)
#
# Endpoint mechanics: ../review-exchange/references/github-review-api.md . Policy is SKILL.md's.
# State lives in <state root>/review-pr/<owner>-<repo>-<n>.json so a later round
# reads a known record instead of re-matching threads by path+line.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
render() { python3 "$here/render.py" "$@"; }

load_ids() {
  f=$1
  owner=$(jq -r .owner "$f"); repo=$(jq -r .repo "$f"); n=$(jq -r .pr "$f")
  state_dir="${REVIEW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}/review-pr"; mkdir -p "$state_dir"
  state="$state_dir/$owner-$repo-$n.json"
}

save_state() {
  cp "$1" "$state"
  echo "state     $state"
}

case ${1:-} in
render)
  render "$2" "$3" ;;

submit)
  f=$2; load_ids "$f"
  event=$(render event "$f")
  [[ $event == APPROVE || $event == COMMENT ]] || { echo "gh-review.sh: refusing event $event" >&2; exit 1; }
  payload=$(mktemp -t gh-review).json; : >"${payload}"
  render payload "$f" > "$payload"
  if [[ ${3:-} == --dry-run ]]; then
    echo "--- event: $event   comments: $(jq '.comments|length' "$payload")"
    jq . "$payload"; exit 0
  fi
  before=$(gh api "repos/$owner/$repo/pulls/$n/reviews" --jq 'length' 2>/dev/null || echo "?")
  resp=$(mktemp -t gh-review-resp).json; : >"${resp}"
  if ! gh api "repos/$owner/$repo/pulls/$n/reviews" --input "$payload" > "$resp"; then
    echo "gh-review.sh: POST failed. A 5xx can still have created the review —" >&2
    echo "  check: gh api repos/$owner/$repo/pulls/$n/reviews   (was $before before this call)" >&2
    echo "  do NOT blind-retry." >&2
    exit 1
  fi
  review_id=$(jq -r .id "$resp")
  jq -r '"posted    \(.html_url)\n          state \(.state)  as \(.user.login)"' "$resp"

  # Pair each posted comment back to its finding on path+line, then PUT the body with the links.
  posted=$(mktemp -t gh-review-posted).json; : >"${posted}"
  gh api "repos/$owner/$repo/pulls/$n/comments?per_page=100" > "$posted"
  linked=$(mktemp -t gh-review-linked).json; : >"${linked}"
  # `first(...) // null` is load-bearing: a bare `(stream) as $m` over an empty
  # stream yields ZERO outputs, so every finding that failed to pair — and every
  # reply record, which never pairs — would be silently dropped from the map.
  jq --slurpfile p "$posted" --arg rid "$review_id" '
    .review_id = ($rid|tonumber)
    | .findings |= map(. as $f
        | (first($p[0][] | select(.path == $f.path and (.line // .original_line) == $f.line)
                         | {url: .html_url, cid: .id}) // null) as $m
        | . + {thread_url: ($m.url // $f.thread_url // null),
               comment_id: ($m.cid // $f.comment_id // null)})' "$f" > "$linked"
  missing=$(jq '[.findings[]|select(.reply_to==null and .thread_url==null)]|length' "$linked")
  [[ $missing -eq 0 ]] || echo "warn      $missing finding(s) did not pair to a posted comment — check the anchors" >&2

  body=$(mktemp -t gh-review-body).md; : >"${body}"
  render body "$linked" > "$body"
  jq -n --rawfile b "$body" '{body:$b}' \
    | gh api -X PUT "repos/$owner/$repo/pulls/$n/reviews/$review_id" --input - \
        --jq '"linked    body updated (\(.body|split("\n")|length) lines)"'
  save_state "$linked"
  ;;

resolve)
  f=$2; load_ids "$f"; shift 2
  for tid in "$@"; do
    gh api graphql -f query="mutation{resolveReviewThread(input:{threadId:\"$tid\"}){thread{isResolved}}}" \
      --jq ".data.resolveReviewThread.thread.isResolved | \"resolved  $tid -> \(.)\""
  done
  ;;

reply)
  f=$2; load_ids "$f"
  jq -n --rawfile b "$4" '{body:$b}' \
    | gh api "repos/$owner/$repo/pulls/$n/comments/$3/replies" --input - --jq '"replied   \(.html_url)"'
  ;;

refresh)
  f=$2; load_ids "$f"
  review_id=$(jq -r '.review_id' "$f")
  [[ $review_id != null ]] || { echo "gh-review.sh: no review_id in $f — nothing to refresh" >&2; exit 1; }
  prev=$(mktemp -t gh-review-prev).md; : >"${prev}"
  gh api "repos/$owner/$repo/pulls/$n/reviews/$review_id" --jq .body > "$prev"
  echo "backup    previous body at $prev"
  body=$(mktemp -t gh-review-body).md; : >"${body}"
  render body "$f" > "$body"
  jq -n --rawfile b "$body" '{body:$b}' \
    | gh api -X PUT "repos/$owner/$repo/pulls/$n/reviews/$review_id" --input - --jq '"refreshed \(.html_url)"'
  save_state "$f"
  ;;

*) sed -n '2,12p' "$0"; exit 1 ;;
esac
