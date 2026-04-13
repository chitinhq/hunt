#!/usr/bin/env bash
set -euo pipefail

render() {
  local fixture="$1"
  # shellcheck disable=SC1091
  export MO_ALLOW_FUNCTION_ARGUMENTS=1
  # Feed fixture as env via jq → shell vars.
  while IFS='=' read -r k v; do export "QUEST_$k"="$v"; done < <(
    jq -r 'to_entries[] | "\(.key)=\(.value)"' "$fixture"
  )
  ./vendor/mo templates/card.html.mustache
}

render tests/fixtures/row-normal.json > /tmp/rendered-normal.html
render tests/fixtures/row-grey.json   > /tmp/rendered-grey.html

# First run creates snapshots; subsequent runs diff.
for name in normal grey; do
  snap="tests/snapshots/row-$name.html"
  rendered="/tmp/rendered-$name.html"
  if [[ ! -f "$snap" ]]; then
    mkdir -p tests/snapshots
    cp "$rendered" "$snap"
    echo "snapshot created: $snap"
  fi
  diff -u "$snap" "$rendered" || { echo "snapshot drift: $name"; exit 1; }
done

# Spot-check: normal output must include party + objective + permalink.
grep -q "SHADOW PACT" /tmp/rendered-normal.html
grep -q "chitin#93"   /tmp/rendered-normal.html
grep -q "shadowpact-20260413-0510" /tmp/rendered-normal.html

# Spot-check: grey output must NOT claim a kill.
! grep -q "DOWNED" /tmp/rendered-grey.html
grep -q "party rested" /tmp/rendered-grey.html

echo "OK"
