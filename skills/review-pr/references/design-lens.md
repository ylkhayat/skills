# The design lens

Correctness has a checklist; design findings tend to come out as "this feels off", which an author
cannot act on. Name the shape instead. Two rules bind this whole file: **a documented repo convention
overrides it** (the `convention files` row of `../review-exchange/config.md`), and **every item here is a
judgement call** — "possible Feature Envy", never a violation. Skip anything tsc or oxlint already
enforces.

Fowler's smell baseline (_Refactoring_, ch.3), *what it is* → *the fix*:

- **Mysterious Name**: a name that doesn't reveal what it does or holds → rename it; if no honest name comes, the design is murky.
- **Duplicated Code**: the same logic shape in more than one hunk → extract it, call it from both.
- **Feature Envy**: a method reaching into another object's data more than its own → move it onto the data it envies.
- **Data Clumps**: the same few fields travelling together → one type, passed whole.
- **Primitive Obsession**: a `string` standing in for a domain concept → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurring → polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forcing scattered edits across the diff → gather what changes together.
- **Divergent Change**: one file edited for several unrelated reasons → split so each module changes for one reason.
- **Speculative Generality**: an abstraction, param or hook for a need the ticket doesn't have → delete it, inline it back.
- **Message Chains**: `a.b().c().d()` navigation the caller shouldn't depend on → hide the walk behind one method.
- **Middle Man**: a class or function that mostly delegates onward → cut it, call the real target.
- **Refused Bequest**: a subclass ignoring most of what it inherits → composition instead.

Six checkable tests on top:

- **The deletion test.** Imagine deleting the module. Complexity vanishes → it was a pass-through, and that's the finding. Complexity reappears across N callers → it earns its keep.
- **One adapter is a hypothetical seam, two is a real one.** A new interface with a single implementation, and nothing that varies across it, is Speculative Generality wearing a seam's clothes.
- **Runs twice.** What happens if this operation runs again, or resumes after a previous run died halfway? "It depends what state was left behind" is a missing reconciliation step, and on an at-least-once trigger (a webhook, a queue, a retry) it is a HIGH.
- **Serialized structurally, or by convention?** Where two actors can touch the same mutable state, look for a lock, a sequential phase, or exclusive ownership. A convention someone has to remember is not serialization.
- **An instruction where structure belongs.** A new comment saying "don't do X", a naming rule, a step someone must remember → ask whether a type, a lint rule, or a runtime check could make the wrong thing impossible instead. A long comment defending a workaround is a finding pointing at the workaround, not at the comment.
- **Ad-hoc branching tangled into an existing flow.** A new conditional or special case dropped into an unrelated path is a design problem, not a style nit — the logic wants its own helper or a state machine. Same for a diff that pushes a file past ~1000 lines: a strong smell, waived only for a clearly organized reason.

## The one fact it's safe because of

Most changes that look scary are safe because of a single fact — "this only drops cache entries that
were already dead", "the caller is the one place that can produce this id". Find that fact before
listing maybes. If it holds, the scary cases die together; if it doesn't, that *is* the review. Spend
the reading there, get it as far down the rung ladder as is cheap, and carry it into the AI;DR as its
middle sentence, with the rung on the metadata line. A long list of maybes that never attacks the
load-bearing fact is a review that reads well and catches nothing.

## The reviewer panel

`pr-context.sh` prints `panel yes` when the diff is ≥10 files, ≥400 changed lines, or touches a path
matching `auth|billing|payment|migration|webhook|permission|policy`. **That is the trigger — do not
second-guess it in either direction.**

**One deferral, and it is not a judgement call either.** When SKILL.md's Phase 1.5 ticket gate has
fired and the reviewer has not yet answered, the panel waits. The size thresholds cannot tell a
genuinely large change from a small one wearing twenty extra files, so on an over-scoped diff `panel
yes` is firing on the symptom the gate is there to report — and three models reading files that are
about to revert is the most expensive noise this skill can produce. Run it in full once the scope is
settled, against whatever survives; a rescope that shrinks the diff below the thresholds means no panel
was ever warranted, and that is the trigger working, not being overridden. On `panel yes`, fan out three read-only reviewers in parallel
with a subagent — **stream E in `fan-out.md`**, dispatched in the same message as the shards — each
on a **different** model (`model: opus`, `sonnet`, `fable`), each handed the
same brief: the diff, the ticket, this file, and `finding-shape.md`. The adversarial signal comes from
model diversity, not from assigned personas — they differ in blind spots, so they miss different things.

Then you are the lead reviewer, not a neutral aggregator. You hold the context they don't: the stack,
the ticket, what the author already deferred.

- **Two reviewers landing on the same thing independently is the strongest signal available** — that one goes in at its own severity.
- **A lone-model finding needs rung 4 to be a HIGH.** Otherwise it's a MEDIUM or a `question`.
- **Deduplicate before authoring.** Three models word one issue three ways, and three comments circling one edit reads as three problems.
- **Say what you threw out** — in the conversation, when you hand the reviewer the panel's results. A dismissed pile they can't see is one they can't overrule. It stays off the PR.
