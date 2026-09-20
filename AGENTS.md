# zenv — Agent Entry Point

## What This Repo Does

zenv is a Swift CLI that stores Zsh secrets in the macOS login Keychain
and installs a `~/.zshrc` hook that loads them and masks `env`/`printenv`.

## Architecture

```
Sources/zenv/        layer 2  ArgumentParser commands
Sources/ZenvCore/    layer 0  Keychain, hook text, migrate, TUI helpers
```

`ZenvCore` must not import ArgumentParser.

## Key Entry Points

| File | Purpose |
|------|---------|
| `Sources/zenv/Zenv.swift` | CLI commands |
| `Sources/ZenvCore/KeychainStore.swift` | SecItem CRUD |
| `Sources/ZenvCore/Hook.swift` | `~/.zshrc` loader and masker |
| `Sources/ZenvCore/Migrate.swift` | Import exports from `~/.zshrc` |
| `Sources/ZenvCore/TUI.swift` | Masked prompts and list table |

## How to Build & Test

```bash
make build
make test
make lint-arch
make lint-all
make clean
```

Without Make:

```bash
swift build -c release
swift test
```

## Storage Model

- **Read/Write:** login Keychain, service `me.hcuong.zenv`, single account `__ZENV_BUNDLE__` (JSON map of uppercase keys → values)
- **Adopt:** leftover one-account-per-key items under the same service merge into the bundle on first read
- **Hook:** `~/.zshrc` markers `# --- zenv safe display start/end ---`
- **Load:** `eval "$(zenv env)"` in interactive Zsh only

## Invariants (never violate)

1. `ZenvCore` has zero ArgumentParser imports
2. zenv does not write secrets into the Zsh env startup file under `$HOME`
3. Sensitive values are never printed by `ls` (always `********`)
4. Hook markers must stay unique
5. Keys are uppercased before storage
6. No secrets hardcoded

## CI

GitHub Actions on push/PR to `main`:
- **test:** `swift test` on macos-latest
- **build:** `swift build -c release` on macos-latest
- **lint-arch:** `scripts/lint-deps.sh`

## Docs Index

- [Architecture](docs/ARCHITECTURE.md)
- [Development guide](docs/DEVELOPMENT.md)
- [Product sense](docs/PRODUCT_SENSE.md)
- [Design docs](docs/design-docs/)
