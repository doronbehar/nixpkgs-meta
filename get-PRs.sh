#!/usr/bin/env bash

set -euo pipefail

if [ ! -x "$GET_PRS_PYTHON" ]; then
  echo "Environment variable \`GET_PRS_PYTHON\` is not set, can't print table.." >&2
  exit 3
fi

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <attr> <other> <gh pr list> <arguments>..." >&2
  exit 1
fi

attr="$1"
shift

gh pr list \
  --search "$attr in:title" \
  --limit 1000 \
  --json title,url,labels,state \
  "$@" | "$GET_PRS_PYTHON" -c '
import json
import sys
from tabulate import tabulate

def fg(hexcolor, text):
    r = int(hexcolor[0:2], 16)
    g = int(hexcolor[2:4], 16)
    b = int(hexcolor[4:6], 16)
    return f"\033[38;2;{r};{g};{b}m{text}\033[0m"

state_colors = {
    "OPEN": "00aa00",
    "MERGED": "8250df",
    "CLOSED": "cf222e",
}
data = sys.stdin.buffer.read()
try:
    prs = json.loads(data)
    del data
    print(tabulate(
        [
            pr | {
                "state": fg(state_colors.get(pr["state"], "ffffff"), pr["state"]),
                "labels": "\n".join(
                    fg(label["color"], label["name"])
                    for label in pr["labels"]
                ),
            }
            for pr in prs
            if pr["title"].startswith("'"$attr"':")
        ],
        headers="keys",
        tablefmt="rounded_grid",
        disable_numparse=True,
    ))
except json.decoder.JSONDecodeError:
    sys.stdout.buffer.write(data)
'
