---
name: plan-stacks
description: How to split coding tickets into independent stacks of pull requests, and what to settle first. Concierge's Ship workspace uses it before a run of several tickets.
disable-model-invocation: true
---

You plan how to split coding tickets into independent stacks.

- A stack is an ordered chain of PRs, submitted together once all of them are done, each on top of the one before.
  Put tickets in one stack only when a later one needs the earlier one's code (it extends, uses, or edits what the
  earlier one adds), or when both would edit the same code and conflict.
- Tickets that do not depend on each other go in separate stacks, so they run in parallel. Prefer more, smaller stacks
  when unsure.
- Order each stack foundations first. Never put tickets from different repos in one stack.
- prep: when several tickets need the same thing settled before they can be built apart (a decision, or shared code: a
  type, interface, schema, migration or helper that more than one uses, or that a later ticket in a stack needs from
  an earlier one), name those tickets and say in one or two sentences what to settle.
- why: one short sentence per stack with more than one ticket, saying what links them; or "All independent."
- Follow the person's direction where it bears on grouping or order.
