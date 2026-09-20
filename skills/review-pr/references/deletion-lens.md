# The deletion lens

`scope-lens.md` asks whether a hunk belongs in **this PR**. `design-lens.md` asks whether it is
**shaped right**. This one asks whether it needs to exist **at all** — and it is the lens that catches
the code both of those wave through, because a guard for a threat nobody checked for reads as diligence
from every other angle.

**One shape, over and over: a construct whose counterparty does not exist.** A guard with no threat, a
helper with no caller, a branch with no producer, a fallback for a shape nothing emits. It compiles, it
is tested, it is commented, and deleting it changes no behaviour.

## The move

For every defensive or accommodating construct in the diff, **name the counterparty out loud, then go
find it.** Not "does this look used" — *who, specifically, produces the input this handles?*

| Construct | Its counterparty | Where you look |
|---|---|---|
| A fallback arm on a field (`?? name`, `\|\| status === 403`) | something that **emits** that field | the producer's serializer — the line that writes the response, not the type that permits it |
| An exported predicate or helper | a **caller** | `grep -rn <name> src/ \| grep -v '\.test\.'` |
| A parameter, option or flag | a call site **passing a non-default** | every call site, not just the ones in the diff |
| A dedup / throttle / "don't stack" guard | a path that actually **produces the duplicate** | the library's own source at its installed version |
| A normalization step (clamp, trim, escape, translate) | an input that is actually **unnormalized** | every producer that reaches it |
| A compatibility shim "for older X" | a deployed **older X** | the other repo at the merge commit that changed it |

**The finding is the grep, and it goes in `repro`.** "This looks unused" is rung 1 and not a finding.
`grep -rn isHandledCallDenial src/ | grep -v '\.test\.'` returning one line — the definition itself —
is rung 2 and settles it. A claim about a *wire* field needs the producer's writing line, because an
allowlist that permits a field is not evidence the field ships.

**Tests keep dead code looking alive.** Nine assertions against a predicate nothing calls is the most
common reason this survives review: coverage tools count it, the diff shows it exercised, and the only
thing that distinguishes it from live code is the grep above. Count test files out when you look for
callers, always.

## Where it does not apply

Never a deletion finding, however unreachable it looks:

- **Anything on the never-simplify list**: validation at a trust boundary, error handling that prevents
  data loss, a security control, accessibility. A guard whose counterparty is *an attacker* has a
  counterparty — you do not get to grep for one.
- A construct whose counterparty is **in an unmerged PR you can see**. That is sequencing, not dead
  code — verify the contract matches and say so as a positive.
- A fallback for a **rollback**, where the author says so. Tolerance for redeploying last week's build
  is a real counterparty; it just has to be stated rather than assumed.
- **A construct a reviewer asked for in an earlier round** — with one exception below.
- Anything the main change needs to compile, typecheck or lint.

**The earlier-round exception, and it is the sharp one.** A reviewer's request is evidence *for* a
construct only while the reason behind it holds. When the premise turns out to be wrong — they asked
for a `name` fallback believing the backend still sent `name` — the construct is dead and the thread is
where you say so. File it as a **`question` on their thread**, never as a unilateral deletion: it is new
information on a decision that was theirs, not a reversal of it.

## Which badge it gets

The lens finds candidates; the **review-exchange** skill owns the badge. The split is one question: **does
its absence change behaviour?**

- **No** — it is merely unused. That is **DEAD `non-blocking`**, with the search in `repro`.
  `render.py` refuses a DEAD finding without one, and refuses any ask but `non-blocking`.
- **Yes** — the construct is not just useless but actively wrong: it suppresses a path, swallows an
  error, deletes a route. That is a **defect at its own severity** whose `fix` happens to be a
  deletion, and it is filed that way. The dedup guard that makes a fallback unreachable is a MEDIUM
  `blocking` bug, not a DEAD.
- **Prefer the deletion as the `fix`** wherever both work, even on the defect. "Delete the guard" is a
  smaller, more reviewable change than "reorder the guard", and it closes the thread permanently
  rather than moving it.

## One record per construct, and cap it

Three deletion findings is a review; ten is a rewrite request the author did not ask for. Past three,
collapse them into **one sentence in the AI;DR** naming the total ("~90 lines of source and 90 of test
guard producers that do not exist") and file only the ones with a behavioural consequence. A helper,
its test and its barrel export are **one** record — same closure rule as `scope-lens.md`.
