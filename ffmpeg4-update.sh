#!/bin/sh

if [ -z "$1" ]; then
	echo no specific package to patch\?
	exit 2
fi
git co -b "$1"-ffmpeg4
git commit --message "$1: use latest ffmpeg"
git push doronbehar

hub pull-request \
	--message "$(git log --oneline -n 1 --format=%B | head -1)" \
	--message "$(cat .m/standard-PR-templates/ffmpeg4.txt)" \
	--browse \
	--edit \
	--push
