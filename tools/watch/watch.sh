#!/bin/bash
# Print every watched M5 repo branch whose head moved since the last run, then record the new heads.
# Usage: watch.sh [--quiet-record]   State: ~/m5/watch/state.tsv (repo<TAB>branch<TAB>sha)
cd "$(dirname "$0")"
REPOS=(
 aurora-silicon/linux:integration/aurora aurora-silicon/aura:main
 omacom/linux-aurora: omacom/m1n1: omacom/omarchy-mac-pkgs: omacom/omarchy-mac-installer:
 rolotrealanis98/m5pro-linux: rolotrealanis98/m4-m5-linux: rolotrealanis98/linux: rolotrealanis98/linux-aurora: rolotrealanis98/m1n1: rolotrealanis98/omarchy-mac-pkgs: rolotrealanis98/mesa:
 edimoldovan/linux-aurora: edimoldovan/m1n1: edimoldovan/omarchy-mac-pkgs: edimoldovan/omarchy-mac-installer: edimoldovan/u-boot: edimoldovan/omarchy-kit:
 TripleU613/Omarchy-M5-Pro: aurora-silicon/mesa: aurora-silicon/u-boot:
)
touch state.tsv; : > new.tsv
for e in "${REPOS[@]}"; do r=${e%%:*}; b=${e#*:}
  if [ -z "$b" ]; then
    # every branch pushed in the last 3 days
    gh api "repos/$r/branches?per_page=100" --paginate -q '.[]|.name+"\t"+.commit.sha' 2>/dev/null | while IFS=$'\t' read -r bn sha; do printf '%s\t%s\t%s\n' "$r" "$bn" "$sha"; done >> new.tsv
  else
    sha=$(gh api "repos/$r/commits/$b" -q .sha 2>/dev/null) && printf '%s\t%s\t%s\n' "$r" "$b" "$sha" >> new.tsv
  fi
done
# open PRs touching T6050/J714 across the main hubs
for r in aurora-silicon/linux aurora-silicon/aura omacom/linux-aurora omacom/m1n1 omacom/omarchy-mac-pkgs omacom/omarchy-mac-installer; do
  gh pr list -R "$r" --state all --limit 40 --search "t6050 OR j714 OR j714s OR \"M5 Pro\" OR \"M5 Max\"" --json number,headRefOid -q '.[]|"'"$r"'\tPR#\(.number)\t\(.headRefOid)"' 2>/dev/null >> new.tsv
done

# People: every repo they pushed to in the last 3 days, each branch head
PEOPLE=(maralcbr scottjones chriskearney malik-na DjDeveloperr joshuaswarren themartiano riverscn RyanTheTide Acelogic LiamRay11 erykwieliczko subedijaidip shawnyeager jondkinney
        rolotrealanis98 edimoldovan betizzel erikwb satchlj joske TripleU613 FatBoy721 cameroncooper
        IronsideXXVI jgoyvaerts kazuhidet andreinita21 fbalazsy Blueemi pixbroker sithglan nickyrice04 Isaac-Duarte)
since=$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ)
for u in "${PEOPLE[@]}"; do
  gh repo list "$u" --limit 200 --json nameWithOwner,pushedAt -q ".[]|select(.pushedAt>\"$since\")|.nameWithOwner" 2>/dev/null | while read -r r; do
    gh api "repos/$r/branches?per_page=100" -q '.[]|.name+"\t"+.commit.sha' 2>/dev/null | while IFS=$'\t' read -r bn sha; do printf '%s\t%s\t%s\n' "$r" "$bn" "$sha"; done
  done
done >> new.tsv
# Anyone on GitHub: repos mentioning the M5 Pro/Max chips, by last push
for q in t6050 j714s j714c j716s "m5 pro linux" "m5 max linux" "omarchy m4" j604 j616s j713 t6040 t8132; do
  gh api -X GET search/repositories -f q="$q pushed:>$since" -q '.items[]|.full_name+"\tREPO\t"+.pushed_at' 2>/dev/null
done >> new.tsv
# The J714 owners' thread
gh api "repos/omacom/linux-aurora/issues/293/comments?per_page=100&since=$since" -q '.[]|"omacom/linux-aurora\t#293\t\(.id) \(.user.login)"' 2>/dev/null >> new.tsv
# omarchyarchive.com: community posts (X, blogs) mentioning the M5 Macs
for q in M5 "M5+Pro" "M5+Max" T6050 J714; do
  curl -fsL "https://omarchyarchive.com/api/search.json?q=$q" 2>/dev/null |
    python3 -c 'import json,sys; [print("omarchyarchive\tPOST\t"+h["url"]+" "+h["title"][:100]) for h in json.load(sys.stdin).get("results",[])]' 2>/dev/null
done >> new.tsv
sort -u new.tsv -o new.tsv
if [ "${1:-}" != --quiet-record ]; then
  comm -23 new.tsv <(sort -u state.tsv)
fi
mv new.tsv state.tsv
