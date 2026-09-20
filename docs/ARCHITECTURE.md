# Architecture

zenv is a Swift CLI. It stores secrets in the macOS login Keychain and loads them in interactive Zsh through `~/.zshrc`.

```mermaid
graph TD
    subgraph "CLI"
        SET[set]
        LS[ls]
        RM[rm]
        MIG[migrate]
        DOC[doctor]
        ENV[env]
        KEYS[keys]
    end
    subgraph "ZenvCore"
        STORE[KeychainStore]
        HOOK[Hook]
        MIGC[Migrate]
        TUI[TUI]
    end
    SET --> TUI
    SET --> STORE
    LS --> STORE
    RM --> STORE
    MIG --> MIGC
    MIG --> STORE
    DOC --> HOOK
    DOC --> STORE
    ENV --> STORE
    KEYS --> STORE
```

## Data flow

`zenv set` writes `kSecClassGenericPassword` with service `me.hcuong.zenv`. `zenv doctor` appends a hook that runs `eval "$(command zenv env)"` and builds `_ZENV_KEYS` from `zenv keys`. New interactive shells get the variables. `zsh -c` does not.

## Files

| Path | Role |
|------|------|
| Keychain | Secret values |
| `~/.zshrc` | Loader and masker |
| `~/.zenv/backups/` | Hook and migrate backups |
