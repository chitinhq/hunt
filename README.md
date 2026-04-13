# Hunt

Kill-cards for the Chitin `/go` flywheel. One HTML page per session at
`https://chitinhq.github.io/hunt/k/<session-id>`.

## What this repo is

A GitHub Action queries the shared Neon `hunt_session` table, renders a Mustache
template per row, and commits the HTML to `gh-pages`. No server, no framework.

## What this repo is NOT

- A web app. Card views are static HTML.
- An auth system. All cards are public.
- A leaderboard. See `chitinhq/sentinel` for agent scorecards.

## Spec

See `chitinhq/workspace:docs/superpowers/specs/2026-04-13-hunt-mvp-design.md`.

## Secrets required by the Action

- `SENTINEL_NEON_URL` — read-only connection string to the shared Neon DB.
