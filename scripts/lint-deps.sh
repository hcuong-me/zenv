#!/usr/bin/env bash
# ZenvCore must not import ArgumentParser.
set -euo pipefail

ERRORS=0
while IFS= read -r file; do
  if grep -q 'import ArgumentParser' "$file"; then
    echo "ERROR: $file imports ArgumentParser."
    echo "       ZenvCore is layer 0 and must not import CLI types."
    ERRORS=$((ERRORS + 1))
  fi
done < <(find Sources/ZenvCore -name '*.swift' 2>/dev/null)

if [[ $ERRORS -eq 0 ]]; then
  echo "lint-deps: ZenvCore has no ArgumentParser imports"
  exit 0
fi
echo "lint-deps: $ERRORS dependency violation(s) found"
exit 1
