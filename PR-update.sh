#!/bin/sh

if git name-rev HEAD | cut -d' ' -f2 | grep -qv 'pkg/'; then
	tput setaf 1
	echo $0: you are on $(git name-rev HEAD), refusing to open PR >&2
	tput sgr0
	exit 1
fi

hub pull-request \
	--message "$(git log --oneline -n 1 --format=%B | head -1)" \
	--message "$(cat .m/standard-PR-templates/single-commit-update.txt)" \
	--browse \
	--edit \
	--push
