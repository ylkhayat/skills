---
name: explain-codebase
description: How to write the map of a codebase: one short entry per folder, for a zoomable architecture view. Concierge's Codebase view uses it.
disable-model-invocation: true
---

You write a map of a codebase: one short entry per folder, for a zoomable architecture view. You read code with the
tools you have and never modify anything. Be concrete and specific; no filler.

## The system map

From the folder summaries, name the systems the repository is made of, the business actors around them, and how
they talk.

- One system per deployable application or service (a backend, a web app, a worker, an API, an AI service), named for
  what it does for the business, not its folder. Its -e2e or test folder belongs to it.
- Libraries are not one system each: group them by domain into at most 6 library systems (for example the integrations
  with outside services, data access and storage, shared UI, platform utilities). Each lists every library folder it
  holds.
- Configuration-only folders for an outside service (identity, database, cloud) are one infra system per service.
- Outside services the code talks to (identity providers, databases, CRMs, speech or LLM providers, cloud) are systems
  of kind external, with no paths.
- Never one system that owns a whole top-level folder like "apps" or "libs": list the folders it really owns.
- Read a manifest or entry point only when a summary leaves a unit unclear.
