#!/bin/sh

if git name-rev HEAD | cut -d' ' -f2 | grep -qv 'pkg/'; then
	tput setaf 1
	echo "$0": you are on "$(git name-rev HEAD)", refusing to open PR >&2
	tput sgr0
	exit 1
fi

git push -u doronbehar

gh pr create \
	--title "$(git log -n 1 --oneline --format=%B "$(env \
		FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
			--header='Choose a git commit to base PR title upon'
		" \
		git flog)" | head -1)" \
	--body-file .m/standard-PR-templates/single-commit-update.txt \
	"$@"
