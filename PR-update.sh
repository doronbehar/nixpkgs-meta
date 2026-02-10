#!/bin/sh

if git name-rev HEAD | cut -d' ' -f2 | grep -qvE '(pkg|nixos|doc)/'; then
    tput setaf 1
    echo "$0": you are on "$(git name-rev HEAD)", refusing to open PR >&2
    tput sgr0
    exit 1
fi

feature_branch="$(git rev-parse --abbrev-ref HEAD)"
# Arbitrarily large number
_best_distance=999999999

# Check a list of possible parent branches
for parent in \
    $(git br | grep 'release-[0-9]' | sort | head -1) \
    $(git br | grep 'staging-[0-9]' | sort | head -1) \
    $(git br | grep 'staging-next-[0-9]' | sort | head -1) \
    python-updates \
    staging-next \
    staging \
    staging-nixos \
    master; do
    if git show-ref --verify --quiet "refs/heads/$parent"; then
        ancestor=$(git merge-base "$feature_branch" "$parent")
        distance=$(git rev-list --count "$ancestor..$feature_branch")

        if [ "$distance" -lt "$_best_distance" ]; then
            _best_distance=$distance
            best_parent=$parent
        fi
    fi
done

if [ -n "$best_parent" ] && [ "$_best_distance" -lt 1000 ]; then
    echo "Best guess for parent branch: $best_parent"
else
    # TODO: Maybe don't exit if --base was used in "$@"?
    echo "No suitable parent branch found."
    exit 2
fi

# Written by Claude, inspired by Nixpkgs' substituteInPlace
replace_literal() {
    string="$1"
    search="$2"
    replace="$3"
    result=""
    while case "$string" in *"$search"*) true;; *) false;; esac; do
        # Get prefix before first match
        prefix="${string%%"$search"*}"
        # Append prefix and replacement to result
        result="$result$prefix$replace"
        # Remove prefix and search string from input
        string="${string#*"$search"}"
    done
    # Append remaining string
    result="$result$string"
    printf '%s\n' "$result"
}

pr_body="$(cat .github/PULL_REQUEST_TEMPLATE.md)"
pr_body="$(replace_literal "$pr_body" "[ ] x86_64-linux" "[x] x86_64-linux")"
pr_body="$(replace_literal \
  "$pr_body" \
  "[ ] Tested basic functionality of all binary files" \
  "[x] Tested basic functionality of all binary files" \
)"
pr_body="$(replace_literal "$pr_body" "[ ] Fits [CONTRIBUTING.md]" "[x] Fits [CONTRIBUTING.md]")"

# The last argument mainly is needed due to the `push.default` line in ./gitconfig
git push -u doronbehar "$(git branch --show-current)"

gh pr create \
    --title "$(git log -n 1 --oneline --format=%B "$(env \
        FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
            --header='Choose a git commit to base PR title upon'
        " \
        git flog)" | head -1)" \
    --body "$pr_body" \
    --base "$best_parent" \
    "$@"
