#!/usr/bin/env bash
# lint-quality.sh — check code quality beyond what golangci-lint covers
set -euo pipefail

ERRORS=0

# Check 1: No fmt.Println in non-command packages (commands may print, internals should return errors)
echo "Checking for fmt.Print in internal packages..."
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  echo "WARNING: $file:$lineno uses fmt.Print in internal package."
  echo "         Internal packages should return errors, not print directly."
  ERRORS=$((ERRORS + 1))
done < <(grep -rn 'fmt\.Print' internal/ --include='*.go' 2>/dev/null || true)

# Check 2: No os.Getenv in internal packages (env access should be in cmd layer)
echo "Checking for os.Getenv in internal packages..."
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  echo "WARNING: $file:$lineno uses os.Getenv in internal package."
  echo "         Environment access should be in cmd/commands or passed as parameters."
  ERRORS=$((ERRORS + 1))
done < <(grep -rn 'os\.Getenv' internal/ --include='*.go' 2>/dev/null || true)

# Check 3: All exported functions have doc comments
echo "Checking exported symbols have doc comments..."
while IFS= read -r file; do
  # Find exported functions/types without a doc comment on the preceding line
  prev_line=""
  line_num=0
  while IFS= read -r current_line; do
    line_num=$((line_num + 1))
    # Check if this line declares an exported function or type
    if echo "$current_line" | grep -qE '^(func|type|var|const) [A-Z]'; then
      # Check if previous line is a comment
      if ! echo "$prev_line" | grep -qE '^\s*//'; then
        echo "WARNING: $file:$line_num exported symbol without doc comment."
        ERRORS=$((ERRORS + 1))
      fi
    fi
    prev_line="$current_line"
  done < "$file"
done < <(find . -name "*.go" -not -path "./.git/*" -not -path "./vendor/*")

# Check 4: No TODO/FIXME without a ticket reference
echo "Checking TODO/FIXME annotations..."
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  if ! echo "$line" | grep -qE '#[0-9]+'; then
    echo "INFO: $file:$lineno TODO/FIXME without ticket reference."
  fi
done < <(grep -rn 'TODO\|FIXME' --include='*.go' . 2>/dev/null || true)

if [[ $ERRORS -eq 0 ]]; then
  echo "✓ lint-quality: all quality checks passed"
  exit 0
else
  echo "✗ lint-quality: $ERRORS issue(s) found"
  exit 1
fi
