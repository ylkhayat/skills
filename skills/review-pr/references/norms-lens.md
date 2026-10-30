# The norms lens

`scope-lens.md` asks whether a hunk belongs in **this PR**, `deletion-lens.md` whether it needs to exist
**at all**. This one asks whether it is done **the way it is written down**: by the house, by the library
it calls, by the language. It catches the code every other lens waves through because it works: the
effect that derives state, the update in a loop next to a driver's bulk call, the hand-rolled retry beside
the client's own.

## The move

1. **List what the diff leans on.** Each library or framework a changed hunk calls, with the version the
   repo pins (`package.json`, the lockfile, `pyproject.toml`), and the house documents that touch the
   area: ADRs under `docs/adr` (or wherever the repo keeps them), `CLAUDE.md`, lint and formatter config.
2. **Read the norm, don't recall it.** For each candidate, open the primary source at that version (the
   library's own docs, its migration guide, the ADR) and quote the rule in one line. A norm you can't
   find written down is not a norm. Drop it.
3. **Compare, and keep only real drift.** The code does it another way, and the source says which way.

| Tier | Where the rule is written | Wins over |
|---|---|---|
| House | ADRs, `CLAUDE.md`, lint/formatter config, the repo's own established pattern (3+ call sites) | everything |
| Ecosystem | the library's official docs and guides, at the pinned version | language |
| Language | the language's style guide, its RFCs/PEPs | — |

**The nearest tier wins.** Code that follows an ADR which departs from the library's docs is aligned.
Name the ADR in your notes, file nothing. A house pattern with three or more call sites counts as house
even unwritten; the drift is then the new code that breaks from it.

## The finding

`severity: NORM`, `ask: non-blocking`, plus:
- `norm`: the rule in one line, in the source's terms ("Don't use an effect to derive state").
- `source`: https link to the exact page or section. Primary documents only: no blogs, no Q&A sites.
- `fix` (rendered `Align:`): the smallest change that brings it in line.
- `claim`: what the drift costs here, concretely (an extra render, N round trips, a swallowed error).
  "Not idiomatic" is not a cost.

One thread per rule per PR: the first place it drifts carries the thread and names the others.

## Exclusions: when not to file

- **It breaks something** (a bug, a leak, a hole). File the defect at its severity; the norm is its fix.
- **The house chose otherwise**, in writing or by an established pattern. That's aligned.
- **The prompt lists it as a deliberate exception** for this repo. The reviewer already decided.
- **Style a formatter or linter owns.** If the tool doesn't flag it, the house doesn't want it flagged.
- **Version mismatch.** The norm is from a newer major than the repo pins. File it only as a note in the
  review body if the upgrade is near.
- **Taste.** Two documented ways and the code uses one: aligned.

Cap: three NORM threads per PR, the costliest first. Past that, list the rest in one line of the review
body. A review drowning in norms reads as a lecture and gets ignored.
