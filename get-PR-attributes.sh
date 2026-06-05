#!/bin/sh

gh pr view --json commits --jq '.commits[] | .messageHeadline' | awk -F: '{print $1}'
