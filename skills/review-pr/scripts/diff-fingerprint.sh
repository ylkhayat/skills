#!/usr/bin/env bash
# Print a fingerprint of PR <n>'s own changes: the file names and their +/- lines, without hunk
# headers or context. A rebase that only moves the PR leaves it unchanged; a real edit changes it.
# The repo comes from the cwd, or from <owner>/<repo> as the second argument.
set -euo pipefail
n=${1:?usage: diff-fingerprint.sh <pr> [owner/repo]}
repo=${2:-"{owner}/{repo}"}
gh api --paginate "repos/$repo/pulls/$n/files" --jq '.[] | .filename, (.patch // "")' \
  | grep -v '^@@' | grep -E '^[-+]|^[^ ]' | shasum | cut -d' ' -f1
