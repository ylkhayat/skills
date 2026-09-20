#!/usr/bin/env bash
# Phase 0 of /review-pr in one call: resolve the PR, compute the merge-base range,
# make the review worktree, fetch everything in parallel, clear stale crit daemons,
# and print a digest. Run it from the main checkout; it leaves you a worktree to cd into.
#
#   pr-context.sh [pr-number]
#
# Why a merge-base range and never `crit --pr`: see SKILL.md Phase 0.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

n=${1:-}
if [[ -z $n ]]; then
  n=$(gh pr view --json number -q .number 2>/dev/null || true)
fi
if [[ -z $n ]]; then
  branch=$(git rev-parse --abbrev-ref HEAD)
  n=$(gh pr list --head "$branch" --json number -q '.[0].number' 2>/dev/null || true)
fi
[[ -n $n ]] || { echo "pr-context.sh: no PR found — pass a number" >&2; exit 1; }

meta=$(gh pr view "$n" --json number,title,body,author,url,baseRefName,headRefName,baseRefOid,headRefOid,state,files,additions,deletions)
read -r head base branch url <<<"$(jq -r '[.headRefOid,.baseRefOid,.headRefName,.url]|@tsv' <<<"$meta")"
owner_repo=$(sed -E 's#.*github.com/([^/]+/[^/]+)/pull/.*#\1#' <<<"$url")

git fetch --quiet origin "$head" "$base" 2>/dev/null || git fetch --quiet
mb=$(git merge-base "$base" "$head")
range="$mb..$head"

wt="$repo_root/.claude/worktrees/review-pr-$n"
if [[ ! -d $wt ]]; then git worktree add --quiet --detach "$wt" "$head"; fi
[[ $(git -C "$wt" rev-parse HEAD) == "$head" ]] || {
  echo "pr-context.sh: worktree HEAD != headRefOid — the PR moved, remove $wt and rerun" >&2; exit 1; }

# Scratch never lands in a checkout — the repo would have to gitignore it.
# ponytail: keyed on the PR number alone; add the repo slug if you ever review
# the same number in two repos at once.
# Scratch root: REVIEW_STATE_DIR wins, else the XDG default. Never inside the checkout,
# and never tied to one agent harness's config dir.
state_root="${REVIEW_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}/review-pr"
out="$state_root/pr-$n"; mkdir -p "$out"
printf '%s' "$meta" > "$out/meta.json"
gh pr diff "$n"                                              > "$out/diff.patch"      &
gh api "repos/$owner_repo/pulls/$n/comments?per_page=100"     > "$out/comments.json"   &
gh api "repos/$owner_repo/pulls/$n/reviews?per_page=100"      > "$out/reviews.json"    &
gh api /user -q .login                                        > "$out/me.txt"          &
wait

me=$(cat "$out/me.txt")

# Round: the badge in our own most recent review body is the source of truth.
round=$(jq -r --arg me "$me" '
  [.[] | select(.user.login==$me)] as $mine
  | if ($mine|length) == 0 then 1
    else ((($mine[-1].body // "") | [scan("Round-([0-9]+)")] | last) as $m
          | if $m then (($m[0]|tonumber) + 1) else (($mine|length) + 1) end)
    end' "$out/reviews.json" 2>/dev/null || echo 1)
[[ $round =~ ^[0-9]+$ ]] || round=$(( $(jq --arg me "$me" '[.[]|select(.user.login==$me)]|length' "$out/reviews.json") + 1 ))

# Ticket id: title, then branch, then body. Absent is not a finding.
ticket=$( { jq -r '.title' "$out/meta.json"; echo "$branch"; jq -r '.body // ""' "$out/meta.json"; } \
          | grep -oE '\b[A-Z]{2,5}-[0-9]+\b' | head -1 || true )

files=$(jq '.files|length' "$out/meta.json")
lines=$(jq '.additions + .deletions' "$out/meta.json")
human=$(jq --arg me "$me" '[.[]|select(.user.login|test("\\[bot\\]$")|not)]|length' "$out/comments.json")
bots=$(jq '[.[]|select(.user.login|test("\\[bot\\]$"))]|length' "$out/comments.json")
risky=$(jq -r '[.files[].path|select(test("auth|billing|payment|migration|webhook|permission|policy";"i"))]|length' "$out/meta.json")
panel=no
if (( files >= 10 || lines >= 400 || risky > 0 )); then panel=yes; fi

# Exactly one crit daemon for this cwd (crit resolves by cwd; a stale one hides comments).
# Kill by the pid in the session file, never by pattern: a `crit` plan review can be
# running in the repo root, and pkill -f "crit _serve" would take it out too.
for sf in $(grep -l "\"cwd\": \"$wt\"" "$HOME"/.crit/sessions/*.json 2>/dev/null || true); do
  pid=$(jq -r '.pid // empty' "$sf")
  [[ -n $pid ]] && kill -9 "$pid" 2>/dev/null || true
  rm -f "$sf"
  echo "cleared   stale crit session $(basename "$sf" .json) (pid $pid)"
done

# The pinned port + range crit.sh reads. Deterministic per PR, so the reviewer's
# tab keeps working across every restart (crit otherwise picks a random one).
crit_port=$("$here/crit.sh" port "$n")
cat > "$out/crit.env" <<ENV
CRIT_PORT=$crit_port
CRIT_RANGE=$range
ENV

# Tooling reviews first, in the background. Skipped cleanly when the repo has no such script.
have() { jq -e --arg s "$1" '.scripts[$s]' package.json >/dev/null 2>&1; }
# One background job, run in sequence: a fresh worktree has no node_modules, and two
# concurrent pnpm scripts each trigger an install into the same store. Redirect at the
# subshell, not just the command — a child inheriting this stdout holds the pipe open
# and the caller reading our digest hangs until typecheck finishes.
(
  cd "$wt" || exit
  { have typecheck && pnpm typecheck; } >"$out/typecheck.log" 2>&1
  { have lint      && pnpm lint;      } >"$out/lint.log"      2>&1
  echo "done" > "$out/tooling.done"
) >/dev/null 2>&1 </dev/null &
disown 2>/dev/null || true

# Launch crit now rather than in Phase 1. Everything it needs is already computed, and
# the reviewer should be reading the diff while Phase 0's triage is still running —
# waiting for the triage to finish first is minutes of dead time for them and buys
# nothing. A failure here must not take the digest down with it.
crit_line=$( (cd "$wt" && REVIEW_DIR="$out" "$here/crit.sh" launch) 2>&1 ) \
  || crit_line="LAUNCH FAILED — cd \"$wt\" && scripts/crit.sh launch   ($crit_line)"

cat <<DIGEST
PR          #$n  $(jq -r .title "$out/meta.json")
author      $(jq -r .author.login "$out/meta.json")   base $(jq -r .baseRefName "$out/meta.json")  head $branch
round       $round
range       $range
worktree    $wt        (cd there for every phase)
context     $out/{meta,comments,reviews}.json  diff.patch
tooling     $out/{typecheck,lint}.log  (sequential, in the background; $out/tooling.done when finished)
size        $files files · $lines lines changed · $risky risky paths
comments    $human human · $bots bot   (reply on these before authoring anything new)
ticket      ${ticket:-none}
panel       $panel   (>=10 files, >=400 lines, or a risky path)
crit        $crit_line
            port $crit_port (pinned)  ·  finish hook $( [ -x "$HOME/.crit/hooks/on_finish_unresolved.sh" ] && echo installed || echo MISSING )
next        relay that URL, then cd "$wt" and dispatch Phase 0 triage + Phase 2 fan-out
DIGEST
