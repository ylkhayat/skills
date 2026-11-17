---
name: simplify-stack-steps
description: How to boil down what the agents of one stack of pull requests each wait on into a few decisions and steps for the person to answer once. Concierge's stack answer uses it.
disable-model-invocation: true
---

Several agents each worked one pull request of the same stack, and each left its own list: decisions it needs from
the person, steps it proposes, things it would make public (a push, a posted reply). Read together they repeat each
other, depend on each other and sometimes pull opposite ways. You turn them into the shortest plan the person can answer
once. You change nothing about what the agents asked: every item you are given ends up in exactly one place.

Decisions (what needs the person's input):
- One decision per real question. When two agents ask the same thing, or one agent's question is settled by another's
  answer, make it one decision whose options each say what every underlying item gets.
- An option is a whole outcome in plain words ("Keep the tool list top-level, and drop the copy inside the state"),
  not an agent's wording. Two to four options. Say in `why` what hangs on it, in one sentence.
- Suggest an option only when the texts, the stack's direction or the person's steer support it; otherwise suggest none.
- A question the person's steer already answers is still listed, with that option suggested.

Steps (what will be done once the decisions are in):
- Merge steps that do the same thing to the same PR or branch. Order them so nothing comes before what it needs: a
  lower PR before the ones built on it, a rebase before the push that depends on it.
- Keep each to one line, starting with a verb, naming the PR by its number.
- A step is `public` when it shows outside the person's machine: a push, a posted reply or comment, a ticket change.
- Leave a step off (`on: false`) when another step replaces it, when it would undo one you kept, or when it only waits
  for someone else ("answer the follow-up once it arrives"). Say why in a few words.

Left out: items that are exact repeats, or that a kept step makes pointless. Give the reason in a few words.

When two items cannot both happen, never keep both: turn the choice into a decision, or keep the one the direction or
the steer supports and leave the other out, saying so.

summary: two sentences at most: what the stack is waiting for, and the one thing that matters most to decide.

The person's steer, when there is one, outranks the agents' own recommendations. The stack's direction, when given,
outranks them too. Never invent a step or an option that none of the items supports.
