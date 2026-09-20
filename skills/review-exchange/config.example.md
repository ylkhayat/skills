# Setup — example

```bash
cp config.example.md config.md    # then rewrite the values; config.md is gitignored
```

Everything in these skills that is true of *your* repos and *your* team, rather than of
reviewing in general, lives in `config.md`. The skills are the orchestration and read
their values from there, so this is the only file you edit.

The values below are one working example, not defaults. A skill that needs a row reads
it from your copy; if a row is blank or wrong for your repo the skill degrades rather
than fails — the tooling rows are all guarded by "skip when the repo has no such
script", and an empty playbook or bot row is just one less input to the review.

| Key | Value | Used by |
|---|---|---|
| `repos` | `acme/web`, `acme/desktop-app` | revise picker |
| `trunk branches` | `main`, `develop` | review-pr stack detection |
| `install` | `pnpm install --prefer-offline` | both |
| `typecheck` / `lint` | `pnpm typecheck` / `pnpm lint` | review-pr Phase 0 |
| `fix` | `pnpm fix:all` (oxfmt, then oxlint --fix) | revise, before `git add` |
| `test` | `pnpm vitest run` | revise repro lines |
| `convention files` | `docs/conventions/*.md`, `.cursor/BUGBOT.md`, `*/.cursor/BUGBOT.md` | revise |
| `review bots` | `cursor[bot]`, `bugbot` | review-pr Stream A triage |
| `playbook skills` | `acme-backend`, `acme-frontend`, `acme-desktop` | review-pr fan-out briefs |
| `issue tracker` | Linear — keys like `ENG-318`; committed work lands in Todo/Backlog, anything cancellable in Triage | review-pr ticket gate, linear-ticket |
| `my login` | `@ylkhayat` | badge provenance in review-exchange |

Illustrations inside the skills still name these same repos and handle. They show the
*shape* of a path or a badge and are never looked up — leave them; the rows above are
the only thing read at runtime.

Nothing here is a path. The skills find their own files relative to themselves, so the
bundle works wherever your agent keeps skills, and scratch state goes to
`${XDG_STATE_HOME:-~/.local/state}` (override with `REVIEW_STATE_DIR`) rather than into
any one tool's config directory.
