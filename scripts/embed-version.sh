#!/usr/bin/env bash
# Embed a release version into Sources/zenv/Zenv.swift before building.
set -euo pipefail

version="${1:?usage: embed-version.sh <version>}"
version="${version#v}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "embed-version.sh: invalid version '$version'" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
file="$root/Sources/zenv/Zenv.swift"

if [[ ! -f "$file" ]]; then
  echo "embed-version.sh: missing $file" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if ! grep -q 'static let version = "' "$file"; then
  echo "embed-version.sh: version constant not found in $file" >&2
  exit 1
fi

sed "s/static let version = \".*\"/static let version = \"${version}\"/" "$file" >"$tmp"
mv "$tmp" "$file"
trap - EXIT

echo "embedded version ${version} into Sources/zenv/Zenv.swift"
