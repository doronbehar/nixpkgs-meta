#!/usr/bin/env bash
#
# Lists Nixpkgs PRs you're involved in that are still "actionable":
#   - currently open PRs, plus
#   - merged PRs whose merge commit has NOT yet reached nixos-unstable
#     (merged, but not landed in a channel bump yet)
#
# Results stream into fzf as soon as each PR is resolved, newest first.
# Pick one or more (Tab to multi-select, auto-accepted if only one
# match) and their URL(s) print to stdout.
#
# Assumes $PWD is a full (non-shallow) nixpkgs checkout with a remote called
# "origin" that can reach nixos-unstable. The "landed" check is an instant `git
# merge-base --is-ancestor` call -- no per-PR network requests.
#
# Requires: gh (authenticated), jq, fzf >= 0.60 (for --accept-nth), git.

set -euo pipefail

REPO="NixOS/nixpkgs"
BRANCH="nixos-unstable"

log() { printf '==> %s\n' "$*" >&2; }

for cmd in gh jq fzf git; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: '$cmd' is required but not found in PATH" >&2; exit 1; }
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "error: \$PWD ($PWD) is not a git checkout -- run this from inside your nixpkgs clone" >&2; exit 1; }

# --accept-nth requires fzf >= 0.60.0
fzf_ver_raw=$(fzf --version)
fzf_ver=${fzf_ver_raw%% *}
IFS=. read -r fzf_major fzf_minor _ <<< "$fzf_ver"
if (( fzf_major == 0 && fzf_minor < 60 )); then
  echo "error: fzf >= 0.60.0 required for --accept-nth (found $fzf_ver)" >&2
  exit 1
fi

log "Fetching ${BRANCH} into $PWD..."
git fetch --quiet origin "$BRANCH"

# landed <merge-commit-sha> -- exit 0 if it has reached $BRANCH, exit != 0 otherwise
landed() {
  git merge-base --is-ancestor "$1" "origin/${BRANCH}" 2>/dev/null
}

# format one PR json object as "display-columns<TAB>url", colored the way
# GitHub colors PR state badges: green = open, gray = draft, purple = merged
fmt_line() {
  jq --raw-output '
    def pad(n): tostring | if length < n then . + (" " * (n - length)) else .[0:n] end;
    def rgb(r; g; b): "\u001b[38;2;\(r);\(g);\(b)m";
    def reset: "\u001b[0m";
    ( if .state == "MERGED" then rgb(130; 80; 223)
      elif .isDraft then rgb(110; 119; 129)
      else rgb(26; 127; 55)
      end ) as $color
    | ( if .isDraft then "DRAFT" else .state end ) as $label
    | ( .createdAt[0:10] ) as $date
    | ("#" + (.number|tostring)) as $num
    | .title as $title
    | .url as $url
    | $color + ([$date, ($label|pad(7)), ($num|pad(7)), $title] | join("  ")) + reset + "\t" + $url
  ' <<< "$1"
}

# --- GraphQL query, reused for both search calls below (auto-paginated) ---
# shellcheck disable=2016
QUERY='
query($q: String!, $endCursor: String) {
  search(query: $q, type: ISSUE, first: 50, after: $endCursor) {
    nodes {
      ... on PullRequest {
        number
        title
        url
        state
        createdAt
        mergedAt
        isDraft
        mergeCommit { oid }
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}'

log "Fetching PRs involving you in ${REPO}, checking against ${BRANCH}..."

gh api graphql \
    --paginate \
    -f query="$QUERY" \
    -f q="repo:${REPO} type:pr -is:closed base:master involves:@me sort:created-desc" \
    --jq '.data.search.nodes[]' \
| while IFS= read -r pr; do
    state=$(jq --raw-output '.state' <<< "$pr")
    if [[ "$state" == "OPEN" ]]; then
      fmt_line "$pr"
    else
      sha=$(jq --raw-output '.mergeCommit.oid // empty' <<< "$pr")
      [[ -n "$sha" ]] && { landed "$sha" || fmt_line "$pr"; }
    fi
  done \
| fzf \
    --multi \
    --select-1 \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=1 \
    --accept-nth=2 \
    --header="Nixpkgs PRs involving you -- open, or merged but not yet on ${BRANCH}"
