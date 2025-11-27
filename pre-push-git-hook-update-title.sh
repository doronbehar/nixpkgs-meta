#!/bin/sh
set -eu

# Use the provided command to select a new title
new_title=$(git log -n 1 --oneline --format=%B "$(env \
    FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
        --header='Choose a git commit to base PR title upon'
    " \
    git flog)" | head -1)

if [ -n "$new_title" ]; then
    gh pr edit "$(git br --show-current)" --title "$new_title"
    echo "✓ Updated PR title to: $new_title"
else
    echo "✗ No title selected, keeping current PR title"
fi
