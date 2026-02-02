#!/bin/sh
set -eu

# Read push information
while read -r local_ref local_sha remote_ref remote_sha; do
    # Skip if deleting a branch
    if [ "$local_sha" = "0000000000000000000000000000000000000000" ]; then
        continue
    fi
    # Get PR information in a single API call
    pr_info=$(gh pr view --json state,number,title,baseRefName)

    if [ -z "$pr_info" ]; then
        echo "WARNING(.git/hooks/pre-push): gh pr view returned empty string - we skip checking PR title etc."
        continue
    fi

    # Extract PR details from the single response
    pr_number=$(echo "$pr_info" | jq -r '.number')
    pr_title=$(echo "$pr_info" | jq -r '.title')
    base_branch=$(echo "$pr_info" | jq -r '.baseRefName')
    pr_state=$(echo "$pr_info" | jq -r '.state')

    # Skip if PR is not open
    if [ "$pr_state" != "OPEN" ]; then
        echo "WARNING(.git/hooks/pre-push): gh pr view found the PR state is '$pr_state', so we skip checking PR title etc."
        continue
    fi

    # Get commit titles (first line of each commit message)
    # Compare against the base branch to get all commits in the PR
    commit_titles=$(git log "origin/$base_branch".."$local_sha" --format=%s)

    # Check if PR title matches any commit title
    title_matches=false
    IFS='
'
    for commit_title in $commit_titles; do
        if [ "$pr_title" = "$commit_title" ]; then
            title_matches=true
            break
        fi
    done
    unset IFS

    if [ "$title_matches" = false ]; then
        echo "⚠️  PR #$pr_number title does not match any commit message"
        echo "   Current PR title: $pr_title"
        echo ""
        # NOTE: we don't have the option to run interactive things here, as
        # `git` takes control of `stdin`, so we instruct the user to use an
        # external script
        echo "To fix the PR title, run .m/pre-push-git-hook-update-title.sh"
    fi
done

exit 0
