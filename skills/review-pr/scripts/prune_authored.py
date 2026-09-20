#!/usr/bin/env python3
"""Make `crit.sh author` idempotent.

`crit comment` only ever appends, so a second author run on the same round shows the
reviewer every finding twice — and a third, three times. Re-authoring after an edit is
the normal way to work (re-badge a finding, fold in a discussion, fix a typo), so the
append has to be undone here rather than remembered by the caller.

Drops this session's own previous comments before the new batch lands. Two things are
never touched, and they are the whole safety argument:

  - a comment with replies — the reviewer engaged with it, so the thread is theirs and
    deleting it would orphan what they wrote
  - a comment by anyone but us — crit is shared with a human who comments in the browser

    prune_authored.py <review.json> [author]
"""
import json, shutil, sys

path = sys.argv[1]
author = sys.argv[2] if len(sys.argv) > 2 else "Claude Code"

doc = json.load(open(path))
shutil.copy(path, path + ".prev")

def keep(c):
    return c.get("author") != author or (c.get("replies") or [])

dropped = kept_with_replies = 0
for entry in (doc.get("files") or {}).values():
    before = entry.get("comments") or []
    after = [c for c in before if keep(c)]
    kept_with_replies += sum(1 for c in after if c.get("author") == author)
    dropped += len(before) - len(after)
    entry["comments"] = after

rc = doc.get("review_comments") or []
new_rc = [c for c in rc if keep(c)]
dropped += len(rc) - len(new_rc)
doc["review_comments"] = new_rc

json.dump(doc, open(path, "w"), indent=2)
note = f" ({kept_with_replies} kept — the reviewer replied)" if kept_with_replies else ""
print(f"pruned    {dropped} stale {author} comment(s){note}", file=sys.stderr)
