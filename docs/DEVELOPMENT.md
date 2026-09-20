# Development Guide

## Setup

### Prerequisites

- Swift 6 (Xcode toolchain)
- macOS 13+
- Zsh at runtime

### Build

```bash
make build
# dist/zenv
swift build -c release
```

### Run locally

```bash
swift run zenv doctor --yes
swift run zenv ls
swift run zenv version
```

Do not point `--yes` doctor at a throwaway machine without reading the hook. It edits `~/.zshrc`.

## Testing

```bash
make test
swift test
```

Keychain round-trip tests use a unique service suffix. SPM hosts that cannot open the login keychain skip those cases.

## Linting

```bash
make lint-arch
make lint-all
```

`scripts/lint-deps.sh` fails if `Sources/ZenvCore` imports ArgumentParser.
`scripts/lint-md.sh` checks project markdown.
`scripts/live-hook.sh` is the optional live Keychain smoke check.

## Project conventions

- Commands live in `Sources/zenv/Zenv.swift`
- Domain logic lives in `Sources/ZenvCore`
- Keys are uppercased at the store boundary
- `ls` never prints values
- Hook markers stay `# --- zenv safe display start ---` and the matching end marker
