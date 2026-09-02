#!/usr/bin/env bash
# Context audit for the skill set. Exits non-zero on any violation.
#
# Guards the four invariants that were broken before minimization:
#   1. frontmatter parses, and `name` matches its directory
#   2. every referenced skill is installed  (caught the geospatial-analysis gap)
#   3. canonical blocks live in exactly one skill  (caught the navigationLinks duplicate)
#   4. no CSP-blocked CDN is actually loaded     (caught the unpkg.com silent failure)
#
# Usage: skills/audit.sh [skills-dir]   (default: the directory holding this script)

set -uo pipefail

DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
FAIL=0

pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=1; }

mapfile -t SKILLS < <(find "$DIR" -mindepth 2 -maxdepth 2 -name SKILL.md | sort)
if [ ${#SKILLS[@]} -eq 0 ]; then echo "no SKILL.md found under $DIR" >&2; exit 2; fi

echo "1. Frontmatter"
for f in "${SKILLS[@]}"; do
    expected=$(basename "$(dirname "$f")")
    out=$(python3 - "$f" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", src, re.S)
if not m:
    print("ERR no frontmatter block"); sys.exit(0)
fm = m.group(1)
name = re.search(r'^name:\s*"?([^"\n]+?)"?\s*$', fm, re.M)
desc = re.search(r'^description:\s*"?(.+?)"?\s*$', fm, re.M | re.S)
if not name: print("ERR missing name"); sys.exit(0)
if not desc: print("ERR missing description"); sys.exit(0)
print(f"OK {name.group(1)} {len(desc.group(1))}")
PY
)
    case "$out" in
        ERR*) fail "$expected: ${out#ERR }" ;;
        *)    read -r _ nm len <<<"$out"
              if [ "$nm" != "$expected" ]; then
                  fail "$expected: frontmatter name is '$nm'"
              else
                  pass "$expected (description ${len} ch)"
              fi ;;
    esac
done

echo "2. Skill cross-references resolve"
# Hyphenated backticked tokens are skill references UNLESS listed here. Anything not
# installed and not listed fails loudly — that is the check that would have caught the
# `geospatial-analysis` delegation pointing at a skill nobody had installed.
NON_SKILL="react-leaflet|@rnmapbox/maps|exactextract|snap-round|filter-then-refine"
for f in "${SKILLS[@]}"; do
    self=$(basename "$(dirname "$f")")
    while read -r ref; do
        [ -z "$ref" ] && continue
        [ "$ref" = "$self" ] && continue
        if [[ "$ref" =~ ^($NON_SKILL)$ ]]; then
            continue
        elif [ -f "$DIR/$ref/SKILL.md" ]; then
            pass "$self -> $ref"
        else
            fail "$self -> $ref  (not installed; if it is a package name add it to NON_SKILL)"
        fi
    done < <(grep -ohE '`[a-z@][a-z0-9@/._-]*-[a-z0-9@/._-]+`' "$f" | tr -d '`' | sort -u)
done

echo "3. Canonical blocks are unique"
# marker -> the one skill allowed to carry it
declare -A OWNER=(
    ["waze.com/ul"]=web-map-builder
    ["maps.apple.com"]=web-map-builder
    ["basemaps.cartocdn.com"]=web-map-builder
    ['dir="rtl"']=web-map-builder
    ["Rubik"]=web-map-builder
    ["og:title"]=github-portfolio-deploy
    ["actions/deploy-pages"]=github-portfolio-deploy
    ["ST_MakeValid"]=geospatial-analysis
    ["EPSG:2039"]=geospatial-analysis
)
for marker in "${!OWNER[@]}"; do
    hits=$(grep -lF -- "$marker" "${SKILLS[@]}" 2>/dev/null | xargs -r -n1 dirname | xargs -r -n1 basename | sort)
    n=$(printf '%s\n' "$hits" | grep -c . || true)
    if [ "$n" -eq 1 ] && [ "$hits" = "${OWNER[$marker]}" ]; then
        pass "$marker -> ${OWNER[$marker]}"
    elif [ "$n" -eq 0 ]; then
        fail "$marker: owner ${OWNER[$marker]} no longer carries it"
    else
        fail "$marker: in $(echo $hits | tr '\n' ' ') (owner: ${OWNER[$marker]})"
    fi
done

echo "4. No CSP-blocked CDN loaded"
# Artifacts allow scripts only from cdnjs/jsdelivr/cdn.tailwindcss.com/code.jquery.com,
# and stylesheets only from fonts.googleapis.com. Prose *mentioning* a blocked host is
# fine; loading from one is not — so match src=/href= attributes only.
if hits=$(grep -nE '(src|href)="https?://(unpkg\.com|esm\.sh|cdn\.skypack\.dev)' "${SKILLS[@]}"); then
    fail "blocked CDN in a load attribute:"; printf '       %s\n' "$hits"
else
    pass "no unpkg.com / esm.sh / skypack in src= or href="
fi

echo "5. Footprint"
python3 - "${SKILLS[@]}" <<'PY'
import os, re, sys
tot_d = tot_b = 0
print(f"  {'skill':26s} {'desc ch':>8s} {'body ch':>8s} {'~body tok':>10s}")
for f in sorted(sys.argv[1:]):
    src = open(f, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n", src, re.S)
    fm, body = (m.group(1), src[m.end():]) if m else ("", src)
    d = re.search(r'^description:\s*"?(.+?)"?\s*$', fm, re.M | re.S)
    dl = len(d.group(1)) if d else 0
    tot_d += dl; tot_b += len(src)
    print(f"  {os.path.basename(os.path.dirname(f)):26s} {dl:8d} {len(src):8d} {round(len(src)/4):10d}")
print(f"  {'-'*56}")
print(f"  {'TOTAL':26s} {tot_d:8d} {tot_b:8d} {round(tot_b/4):10d}")
print(f"  always-loaded (descriptions only): {tot_d} ch / ~{round(tot_d/4)} tok")
PY

echo
[ $FAIL -eq 0 ] && echo "audit: PASS" || echo "audit: FAIL"
exit $FAIL
