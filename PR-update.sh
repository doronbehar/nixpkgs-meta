#!/bin/sh

# If a branch name is passed as the first argument, use it; otherwise detect current branch.
# We consume it from "$@" so the remainder can be forwarded to `gh pr create`.
if [ $# -gt 0 ] && git show-ref --verify --quiet "refs/heads/$1"; then
    feature_branch="$1"
    shift
else
    feature_branch="$(git branch --show-current)"
    if [ -z "$feature_branch" ]; then
        tput setaf 1
        echo "$0: not on any branch (detached HEAD), refusing to open PR" >&2
        tput sgr0
        exit 1
    fi
fi

if ! echo "$feature_branch" | grep -qE '(pkg|nixos|doc)/'; then
    tput setaf 1
    echo "$0: branch '$feature_branch' has no standard prefix like 'pkg', 'nixos' or 'doc', refusing to open PR" >&2
    tput sgr0
    exit 1
fi

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
    found=false
    while case "$string" in *"$search"*) true;; *) false;; esac; do
        found=true
        # Get prefix before first match
        prefix="${string%%"$search"*}"
        # Append prefix and replacement to result
        result="$result$prefix$replace"
        # Remove prefix and search string from input
        string="${string#*"$search"}"
    done
    # Append remaining string
    result="$result$string"
    if ! $found; then
        printf 'replace_literal: pattern not found: %s\n' "$search" >&2
        printf 'replace_literal: input string is:\n%s\n' "$string" >&2
        return 1
    fi
    printf '%s\n' "$result"
}

# Requires gum https://github.com/charmbracelet/gum (packaged in Nixpkgs)
selections_tmpfile="$(mktemp --tmpdir nixpkgs-pr-selection.XXXX.md)"
pr_body="$(cat .github/PULL_REQUEST_TEMPLATE.md)"
echo "$pr_body" | grep -E -- '^(\s*)- ' \
  | gum choose \
    --no-show-help \
    --no-limit \
    --height=40 \
    --selected='  - [ ] x86_64-linux' \
    --selected='- [ ] Tested basic functionality of all binary files\, usually in `./result/bin/`.' \
    --selected='- [ ] Follows the [automation/AI policy].' \
    --selected='- [ ] Fits [CONTRIBUTING.md]\, [pkgs/README.md]\, [maintainers/README.md] and other READMEs.' \
  > "$selections_tmpfile"
while read -r selection; do
  pr_body="$(replace_literal "$pr_body" \
    "$selection" \
    "$(replace_literal "$selection" "- [ ]" "- [x]")" \
  )"
done < "$selections_tmpfile"
rm "$selections_tmpfile"

git push -u doronbehar "$feature_branch"

gh pr create \
    --title "$(git log -n 1 --oneline --format=%B "$(env \
        FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
            --header='Choose a git commit to base PR title upon'
        " \
        git flog "$feature_branch")" | head -1)" \
    --body "$pr_body" \
    --base "$best_parent" \
    --head "doronbehar:$feature_branch" \
    "$@"
