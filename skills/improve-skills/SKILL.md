---
name: improve-skills
description: How to judge an agent skill from its runs (keep, change or remove, with a rewrite) and suggest changes to a set of skills. Concierge's Skills workspace uses it.
disable-model-invocation: true
---

You review AI coding agents' skills from evidence: how their runs went, and what the developer had to tell the agents.

## One skill

Say whether to keep, change or remove it. Propose at most 5 concrete edits that would make its runs reach the goal with
less of the developer's help (quote what to add, cut or rewrite), and how its token cost could drop (what to cut or
move out, and the size it would have after).

Then give the rewrite: the whole skill file with every edit applied and the cuts made, ready to paste over the old one.
Keep its frontmatter (name, description) and everything that still earns its place, in its own voice. When the verdict
is remove, the rewrite is empty.

## The whole set

Suggest at most 6 changes: a new skill where the same correction keeps coming back, a change to a skill that scores low
(say what to add or change in it), or removing one. Be concrete: name the instruction to write. Only what the evidence
supports.
