#!/usr/bin/env bash
# Pull hunt_session rows, render one HTML per row, plus k/latest.html redirect.
# Env: SENTINEL_NEON_URL (required), OUT_DIR (default: ./public)
set -euo pipefail

: "${SENTINEL_NEON_URL:?SENTINEL_NEON_URL required}"
OUT_DIR="${OUT_DIR:-public}"
mkdir -p "$OUT_DIR/k"

MO="$(dirname "$0")/../vendor/mo"
TMPL="$(dirname "$0")/../templates/card.html.mustache"
NARR="$(dirname "$0")/narrator.sh"

# Column list matches fixture env-var shape.
SESSIONS=$(psql "$SENTINEL_NEON_URL" -At -F '|' -c "
  SELECT session_id, party_name, encounter,
         COALESCE(headline,''),
         xp_awarded,
         COALESCE(rarity,''),
         to_char(COALESCE(ended_at,started_at),'YYYY-MM-DD'),
         COALESCE(extract(epoch FROM ended_at - started_at)::int, 0),
         (party::text),
         (drops::text),
         status
  FROM hunt_session
  ORDER BY COALESCE(ended_at,started_at) DESC
")

latest_nongrey=""

while IFS='|' read -r sid pname enc hl xp rarity date dur_sec party_json drops_json status; do
  [[ -z "$sid" ]] && continue
  dur_min=$(( dur_sec / 60 ))
  level=$(( xp / 500 + 1 ))
  drop_count=$(echo "$drops_json" | python3 -c 'import json,sys;print(len(json.loads(sys.stdin.read() or "[]")))')
  # Soulforge↔Hunt boundary 2a: render class only, never soul name.
  # See workspace:docs/strategy/soulforge-hunt-boundary-2026-04-13.md
  party_list=$(echo "$party_json" | python3 -c '
import json,sys,os
m={}
with open(os.path.join(os.path.dirname(sys.argv[1]),"..","data","soul-to-class.tsv")) as f:
    next(f)
    for line in f:
        k,v=line.rstrip("\n").split("\t"); m[k]=v
out=[]
for s in json.loads(sys.stdin.read() or "[]"):
    cls=s.get("class") or m.get(s.get("soul",""),"")
    if cls: out.append(cls)
print("  ".join(out))
' "$0")
  # Short hash for subtitle
  hash=$(printf '%s' "$sid" | shasum | cut -c1-4)
  is_grey="false"; (( xp == 0 )) && is_grey="true"

  # Derive drops_label
  if (( drop_count == 0 )); then
    drops_label="drop: none"
  elif (( drop_count == 1 )); then
    first_url=$(echo "$drops_json" | python3 -c 'import json,sys;d=json.loads(sys.stdin.read());print(d[0].get("ref",d[0].get("url","")))')
    drops_label="drop: $first_url"
  else
    drops_label="drops: $drop_count"
  fi

  # Narrator fallback if headline blank
  if [[ -z "$hl" ]]; then
    if [[ "$is_grey" == "true" ]]; then
      hl="(party rested — 0 drops)"
    else
      hl=$("$NARR" headline "$pname" "quarry" 0 0 "$dur_sec" "$dur_sec" 0 "$drop_count")
    fi
  fi

  subtitle=$("$NARR" subtitle "$level" "$dur_min" "$drop_count" "$xp" "$hash")

  rarity_label=$(echo "$rarity" | tr '[:lower:]' '[:upper:]' | tr '_' ' ')

  # Export env for mo
  export HUNT_session_id="$sid"
  export HUNT_party_name="$pname"
  export HUNT_encounter="$enc"
  export HUNT_level="$level"
  export HUNT_party_list="$party_list"
  export HUNT_quarry=""   # quarry column extension (Phase 2); headline carries it for MVP
  export HUNT_status_label="$([[ "$status" == "won" ]] && echo "DOWNED" || echo "${status^^}")"
  export HUNT_narrative_line1=""
  export HUNT_narrative_line2=""
  export HUNT_narrative_line3=""
  export HUNT_xp_awarded="$xp"
  export HUNT_drops_label="$drops_label"
  export HUNT_rarity_label="$rarity_label"
  export HUNT_headline="$hl"
  export HUNT_subtitle="$subtitle"
  export HUNT_permalink="chitinhq.github.io/hunt/k/$sid"
  export HUNT_date="$date"
  export HUNT_is_grey="$is_grey"

  # Empty narrative for MVP (moves carry it Phase 2); use headline fallback.
  export HUNT_narrative_line1="$hl"

  "$MO" "$TMPL" > "$OUT_DIR/k/$sid.html"

  if [[ "$is_grey" == "false" && -z "$latest_nongrey" ]]; then
    latest_nongrey="$sid"
  fi
done <<< "$SESSIONS"

# k/latest.html: meta-refresh redirect to newest non-grey, else newest overall.
if [[ -z "$latest_nongrey" ]]; then
  latest_nongrey=$(echo "$SESSIONS" | head -n1 | cut -d'|' -f1)
fi
cat > "$OUT_DIR/k/latest.html" <<EOF
<!doctype html><meta http-equiv="refresh" content="0; url=$latest_nongrey.html">
EOF

echo "rendered to $OUT_DIR/k/"
