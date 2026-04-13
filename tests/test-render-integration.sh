#!/usr/bin/env bash
set -euo pipefail

# Need migration SQL. Fetch from sibling workspace if present, else skip.
WS_MIGRATION="../workspace/sentinel/migrations/004_quest_session.sql"
[[ -f "$WS_MIGRATION" ]] || { echo "SKIP: $WS_MIGRATION not found (run from hunt repo with workspace sibling)"; exit 0; }

CID=$(docker run -d --rm -e POSTGRES_PASSWORD=test -p 5547:5432 postgres:16-alpine)
trap "docker rm -f $CID >/dev/null; rm -rf /tmp/quest-out" EXIT

export SENTINEL_NEON_URL="postgres://postgres:test@127.0.0.1:5547/postgres"
for _ in $(seq 1 30); do pg_isready -d "$SENTINEL_NEON_URL" -q && break; sleep 1; done

psql -d "$SENTINEL_NEON_URL" -v ON_ERROR_STOP=1 -f "$WS_MIGRATION"

# Seed: one normal won row + one grey row.
psql -d "$SENTINEL_NEON_URL" -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO quest_session (session_id, started_at, ended_at, party_name, encounter, party,
  loot, moves, xp_awarded, rarity, status)
VALUES
  ('sp-won','2026-04-13T05:10:00Z','2026-04-13T05:24:00Z','SHADOW PACT','raid',
   '[{"soul":"sun-tzu"}]'::jsonb,
   '[{"kind":"pr","ref":"#111","url":"https://x/pr/111"}]'::jsonb,
   '[]'::jsonb, 120, 'flawless', 'won'),
  ('sp-grey','2026-04-13T08:20:00Z','2026-04-13T08:28:00Z','SHADOW PACT','strike',
   '[{"soul":"sun-tzu"}]'::jsonb, '[]'::jsonb, '[]'::jsonb, 0, NULL, 'won');
SQL

mkdir -p /tmp/quest-out
OUT_DIR=/tmp/quest-out bash scripts/render.sh

[[ -f /tmp/quest-out/q/sp-won.html ]]   || { echo "missing sp-won"; exit 1; }
[[ -f /tmp/quest-out/q/sp-grey.html ]]  || { echo "missing sp-grey"; exit 1; }
[[ -f /tmp/quest-out/q/latest.html ]]   || { echo "missing latest"; exit 1; }

# latest must redirect to the non-grey row
grep -q 'url=sp-won.html' /tmp/quest-out/q/latest.html || { echo "latest wrong target"; exit 1; }

grep -q 'SHADOW PACT' /tmp/quest-out/q/sp-won.html
grep -q 'party rested' /tmp/quest-out/q/sp-grey.html

# Soulforge↔Hunt boundary 2a: soul names MUST NOT leak into public HTML party strip.
# Fixture seeds party with soul="sun-tzu"; rendered HTML must show class "Time Mage" instead.
if grep -q 'sun-tzu' /tmp/hunt-out/k/sp-won.html; then
  echo "BOUNDARY VIOLATION: soul name 'sun-tzu' rendered in public HTML"; exit 1
fi
grep -q 'Time Mage' /tmp/hunt-out/k/sp-won.html || { echo "class 'Time Mage' missing from party strip"; exit 1; }

echo "OK"
