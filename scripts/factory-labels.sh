#!/usr/bin/env bash
# Creates the factory stage labels on a repo. Safe to re-run.
# usage: bash scripts/factory-labels.sh [owner/repo]   (defaults to the current repo)
set -euo pipefail
REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
mk() { gh label create "$1" -R "$REPO" --color "$2" --description "$3" --force; }
mk factory:planned     FBCA04 "Plan posted; waiting for human approval"
mk factory:ready       0E8A16 "Plan approved; OK to build"
mk factory:building    1D76DB "Build session running"
mk factory:in-review   5319E7 "PR open; waiting for human review"
mk factory:needs-human D93F0B "Agent escalated; needs a human decision"
echo "Factory labels ready on $REPO"
