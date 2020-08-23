#!/bin/sh

git checkout master
git pull
git checkout -B update-gotify
nix-shell maintainers/scripts/update.nix --argstr package gotify-server
git add pkgs/\*gotify\*
git commit -m "$(git diff --cached \*version.nix | tail -2 | awk -F\" \
	'{ prev_ver=$2; getline; next_ver=$2 } END { printf("gotify-server: %s -> %s\n", prev_ver, next_ver) }' \
)"
git push -f doronbehar update-gotify

./PR-update.sh
