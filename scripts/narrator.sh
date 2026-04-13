#!/usr/bin/env bash
# Hunt narrator grammar picker. Spec §Narrator grammar.
# Flourish precedence: Limit Break > No Continues > MP conserved > All Drops.
# (Summoned <soul> not in MVP — requires soul rarity table.)
set -euo pipefail

FF_VERBS=(felled sundered reaped banished overdrove vanquished cleaved eclipsed)

pick_verb() {
  local party="$1"
  local pool=( "${FF_VERBS[@]}" )
  # Staleness: if NEON URL set, exclude last 3 verbs for this party.
  if [[ -n "${SENTINEL_NEON_URL:-}" ]]; then
    mapfile -t used < <(psql "$SENTINEL_NEON_URL" -At -c \
      "SELECT split_part(headline,' ',2)
       FROM hunt_session
       WHERE party_name = '${party//\'/\'\'}'
         AND headline IS NOT NULL
       ORDER BY ended_at DESC NULLS LAST LIMIT 3" 2>/dev/null || true)
    for u in "${used[@]}"; do
      pool=( "${pool[@]/$u}" )
    done
  fi
  # Rebuild to drop empties
  local clean=()
  for v in "${pool[@]}"; do [[ -n "$v" ]] && clean+=("$v"); done
  (( ${#clean[@]} > 0 )) || clean=( "${FF_VERBS[@]}" )   # fallback
  echo "${clean[$RANDOM % ${#clean[@]}]}"
}

pick_flourish() {
  local crit="$1" retries="$2" dur="$3" median="$4" rare="$5" drops="$6"
  if (( crit > 2 ));                     then echo "Limit Break";  return; fi
  if (( retries == 0 ));                 then echo "No Continues"; return; fi
  if (( dur < median ));                 then echo "MP conserved"; return; fi
  if (( drops >= 3 ));                   then echo "All Drops";    return; fi
  echo ""
}

case "${1:-}" in
  headline)
    party="${2:?party}"
    quarry="${3:?quarry}"
    crit="${4:?crit}"; retries="${5:?retries}"
    dur="${6:?duration}"; median="${7:?median}"
    rare="${8:?rare}"; drops="${9:?drops}"
    verb="$(pick_verb "$party")"
    fl="$(pick_flourish "$crit" "$retries" "$dur" "$median" "$rare" "$drops")"
    if [[ -n "$fl" ]]; then
      printf "%s %s %s — %s\n" "$party" "$verb" "$quarry" "$fl"
    else
      printf "%s %s %s\n" "$party" "$verb" "$quarry"
    fi
    ;;
  subtitle)
    lv="${2:?level}"; dur="${3:?duration_min}"; drops="${4:?drops}"
    xp="${5:?xp}"; hash="${6:?hash}"
    printf "Lv%s · %sm · %sd · +%sxp · %s\n" "$lv" "$dur" "$drops" "$xp" "$hash"
    ;;
  *) echo "usage: $0 {headline|subtitle} ..." >&2; exit 2 ;;
esac
