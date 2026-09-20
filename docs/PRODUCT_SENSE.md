# Product Sense

## Problem

Developers store API keys in shell rc files. Those values show up in `env`, in screen shares, and in files agents can read.

## Target User

macOS developer using Zsh who wants secrets in Keychain and masked `env` output.

## User Journeys

### First-time setup

```
$ zenv doctor
Using Zsh shell
~/.zshrc exists
zenv shell hook is not installed
Shell hook installed successfully
Please restart your terminal or run: source ~/.zshrc
```

### Adding a secret

```
$ zenv set
  Key: STRIPE_SECRET_KEY
  Value: ********
Updated STRIPE_SECRET_KEY
Run 'source ~/.zshrc' or restart your terminal to use this variable.
```

## Design Decisions

1. Masked prompts so values never enter argv or history
2. Hook in `~/.zshrc` only, so Keychain I/O stays interactive
3. Keychain at rest instead of a 0600 file
4. Manual `source ~/.zshrc` after set. A child cannot change the parent env

## Non-goals

- Linux
- Multi-shell support
- Cloud sync (`kSecAttrSynchronizable` stays off)
- Per-project variable scoping
- Loading secrets in non-interactive `zsh -c` by default
