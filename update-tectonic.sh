#!/bin/sh

git checkout master
git pull
git checkout -B pkg/tectonic
nix-update --commit --version-regex 'tectonic%40(.*)' -- tectonic
git push -f doronbehar pkg/tectonic

./PR-update.sh
