# Plans

Implementation plans for Griss live here as markdown files, moving through a
four-stage lifecycle — one subdirectory each:

- **`backlog/`** — rough ideas, unscoped. Not ready to work on.
- **`ready/`** — fully specced. Anyone (human or agent) could pick it up.
- **`in-progress/`** — actively being implemented. Kept current as decisions
  are made.
- **`done/`** — shipped. Includes an accurate record of what was actually
  built, deviations included.

Movement is one-directional in the normal case:
`backlog → ready → in-progress → done`. Moving backwards is fine if scope
changes or work is paused — just update `status` and `updated`.

For the milestone-level roadmap (M0–M4), see [`docs/PLAN.md`](../docs/PLAN.md)
— the original design brief. Plans in here are the next concrete slice of
that roadmap, specced in enough detail to implement directly.

## Naming

Kebab-case filenames describing the work: `add-static-enemies.md`,
`m2-pressure.md`. Names stay stable across the lifecycle; only the
directory changes.

## Frontmatter

Every plan starts with:

```yaml
---
title: <short title>
status: Ready         # Backlog | Ready | In Progress | Complete
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Template

```markdown
---
title: <short title>
status: Ready
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <Title>

## Goal
One or two sentences on what this plan achieves and why.

## Context
Background, constraints, links to related plans or docs.

## Approach
The intended implementation — detail should match the risk of the work.

## Tasks
- [ ] High-level checklist of the work.

## Open questions
Anything unresolved. Resolve or delete these before moving to `ready/`.
```

A `done/` plan additionally gets:

```markdown
## Overview
What was built, in a few sentences, for someone reading this a year from
now who wasn't involved.

## Architecture
How the pieces fit together, key files touched, and any deviations from
the original approach — with reasons. Deviations are the most valuable
part; capture them honestly.
```

## Rules

- One `in-progress/` plan per stream of work is the norm — if several pile
  up, something has stalled.
- Don't delete plans from `done/`. They're the historical record.
- An abandoned plan moves to `done/` with `status: Complete` and an
  Overview explaining why it was dropped, rather than rotting in
  `in-progress/`.
