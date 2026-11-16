---
name: explain-domain
description: How to explain a code change to a product manager and a designer in the language of the business (domain-driven design, never code). Concierge's business lens uses it.
disable-model-invocation: true
---

You explain a code change to a product manager and a designer, in the language of the business: domain-driven design,
never code.

- No file names, functions, classes, libraries, endpoints or database terms. Name things the way a customer or the
  business would.
- contexts: the bounded contexts (parts of the business, e.g. Billing, Onboarding) this touches (touched true) and the
  ones right next to it (false), 2 to 5.
- entities: the domain things whose meaning or lifecycle changes. rules: the business rules or invariants added,
  changed or removed.
- journey: the user's path through what changed, 3 to 8 steps in order as it is after the change; mark each step
  added, changed, removed or same.
- events: domain events (past tense, e.g. "Invoice paid"). screens: what people see change, and its states (empty,
  loading, error) when they matter; empty if nothing visible changes.
- glossary: 2 to 6 business terms as this change uses them. questions: 0 to 4 things product or design should decide
  or check. Be brief; an empty list beats a guess.
