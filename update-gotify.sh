#!/bin/sh

git checkout master
git pull
git checkout -B pkg/gotify
pkgs/servers/gotify/update.sh
git add pkgs/\*gotify\*
git commit -m "$(git diff --cached \*version.nix | tail -2 | awk -F\" \
	'{ prev_ver=$2; getline; next_ver=$2 } END { printf("gotify-server: %s -> %s\n", prev_ver, next_ver) }' \
)"
git push -f doronbehar pkg/gotify/server/update

./PR-update.sh
