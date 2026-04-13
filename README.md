# Quest

Quest-logs for the Chitin `/go` flywheel. One HTML page per session at
`https://chitinhq.github.io/quest/q/<session-id>`.

## What this repo is

A GitHub Action queries the shared Neon `quest_session` table, renders a Mustache
template per row, and commits the HTML to `gh-pages`. No server, no framework.

## What this repo is NOT

- A web app. Quest-log views are static HTML.
- An auth system. All quest-logs are public.
- A leaderboard. See `chitinhq/sentinel` for agent scorecards.

## Spec

See `chitinhq/workspace:docs/superpowers/specs/2026-04-13-hunt-mvp-design.md`
(renamed under workspace#382).

## Secrets required by the Action

- `SENTINEL_NEON_URL` — read-only connection string to the shared Neon DB.
