#!/usr/bin/env bash
# lint-md.sh — lint markdown files for consistency
set -euo pipefail

ERRORS=0

# Check 1: All markdown files have a top-level heading
echo "Checking markdown files have H1..."
while IFS= read -r file; do
  if ! head -5 "$file" | grep -q '^# '; then
    echo "ERROR: $file missing top-level heading (# Title)"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find . -name "*.md" -not -path "./.git/*" -not -path "./.agents/*" -type f)

# Check 2: No placeholder content
echo "Checking for placeholder content..."
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  echo "ERROR: $file:$lineno contains placeholder text."
  ERRORS=$((ERRORS + 1))
done < <(grep -rn 'TODO:\|FIXME:\|PLACEHOLDER\|<INSERT\|TBD' --include='*.md' . --exclude-dir='.agents' 2>/dev/null || true)

# Check 3: No broken internal links (relative paths)
# Only check links in project-owned docs (not .agents, not specs)
echo "Checking internal links..."
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  # Extract link from [text](url) — use awk for BSD/macOS compatibility
  link=$(echo "$line" | awk -F'[()]' '{for(i=1;i<=NF;i++) if($i ~ /^[a-z]/) {print $i; exit}}')
  # Skip empty, http, hash-only, or image links
  [[ -z "$link" ]] && continue
  [[ "$link" == http* ]] && continue
  [[ "$link" == \#* ]] && continue
  # Skip links that look like code (contain spaces, special chars)
  [[ "$link" == *" "* ]] && continue
  target="$(dirname "$file")/$link"
  # Check file or directory existence
  if [[ ! -e "$target" ]]; then
    echo "WARNING: $file references '$link' which does not exist"
    ERRORS=$((ERRORS + 1))
  fi
done < <(grep -rn '\[.*\](.*)' --include='*.md' . --exclude-dir='.agents' --exclude-dir='specs' 2>/dev/null | grep -v 'http' || true)

if [[ $ERRORS -eq 0 ]]; then
  echo "✓ lint-md: all markdown checks passed"
  exit 0
else
  echo "✗ lint-md: $ERRORS issue(s) found"
  exit 1
fi
