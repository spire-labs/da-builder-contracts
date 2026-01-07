#!/bin/bash

set -e

# Move to the root of the git repository
cd "$(git rev-parse --show-toplevel)"

# Fetch the latest changes from the main branch
git fetch origin main

# Get the list of changed Solidity files against the main branch
changed_files=$(git diff --name-only origin/main...HEAD -- src/contracts | grep ".sol$" || true)

if [ -z "$changed_files" ]; then
  echo "No Solidity files changed in src/contracts compared to the main branch."
  exit 0
fi

echo "Checking for version changes in modified contracts..."

for file in $changed_files; do
  # Check if the file implements ISemver by looking for the version function
  if grep -q "function version()" "$file"; then
    echo "Contract $file implements ISemver."

    # Check if the _VERSION constant was changed against the main branch
    if ! git diff origin/main...HEAD -- "$file" | grep -E -q "^[[:space:]]*[+-].*_VERSION"; then
      echo "Error: Contract $file implements ISemver and was modified, but its _VERSION was not updated."
      exit 1
    fi
  fi
done

echo "All modified ISemver contracts have updated versions."
exit 0
