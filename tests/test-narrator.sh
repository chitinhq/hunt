#!/usr/bin/env bash
set -euo pipefail

# Subtitle is deterministic, easiest to pin.
got=$(bash scripts/narrator.sh subtitle 5 14 3 120 a4f9)
want="Lv5 · 14m · 3d · +120xp · a4f9"
[[ "$got" == "$want" ]] || { echo "subtitle: got='$got' want='$want'"; exit 1; }

# Headline: flourish deterministic given stats; verb pool nondeterministic but must come from FF table.
# Limit Break triggers on crit_count > 2.
head=$(bash scripts/narrator.sh headline "SHADOW PACT" "chitin#93" 3 0 840 840 0 1)
echo "$head" | grep -q "^SHADOW PACT " || { echo "headline missing party prefix: $head"; exit 1; }
echo "$head" | grep -q " chitin#93 — Limit Break$" || { echo "headline flourish wrong: $head"; exit 1; }

# Verb must be from the FF table.
verb=$(echo "$head" | awk '{print $3}')
case "$verb" in
  felled|sundered|reaped|banished|overdrove|vanquished|cleaved|eclipsed) : ;;
  *) echo "bad verb: $verb"; exit 1 ;;
esac

# No Continues triggers on retries==0 when crit<=2.
head=$(bash scripts/narrator.sh headline "SHADOW PACT" "chitin#93" 0 0 840 840 0 1)
echo "$head" | grep -q " — No Continues$" || { echo "No Continues flourish: $head"; exit 1; }

# All Drops triggers at drop_count>=3 when higher-priority flourishes don't.
head=$(bash scripts/narrator.sh headline "SHADOW PACT" "chitin#93" 1 5 840 840 0 3)
echo "$head" | grep -q " — All Drops$" || { echo "All Drops flourish: $head"; exit 1; }

# MP conserved triggers when duration < median and crit<=2 and retries>0.
head=$(bash scripts/narrator.sh headline "SHADOW PACT" "chitin#93" 0 2 100 500 0 1)
# No Continues beats MP conserved because retries=2 → No Continues disqualified.
# crit<=2 and retries>0 and duration<median and drop<3 → MP conserved.
echo "$head" | grep -q " — MP conserved$" || { echo "MP conserved flourish: $head"; exit 1; }

echo "OK"
