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
    staging-next \
    staging \
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


git push -u doronbehar

gh pr create \
	--title "$(git log -n 1 --oneline --format=%B "$(env \
		FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
			--header='Choose a git commit to base PR title upon'
		" \
		git flog)" | head -1)" \
	--body-file .m/standard-PR-templates/single-commit-update.txt \
    --base "$best_parent" \
	"$@"
