# zenv

Secure environment variable manager for zsh. Store sensitive values safely without exposing them in shell history or screen recordings.

## Features

- **No shell history leaks** — TUI input prevents sensitive values from appearing in `.zsh_history`
- **Masked display** — Values hidden as `********` in `env`/`printenv` output
- **Full compatibility** — Applications still access real values via standard APIs
- **Simple TUI** — Interactive prompts for setting variables
- **Migration support** — Move existing exports from `.zshrc` to `.zshenv`

## Installation

### Homebrew (recommended)

```bash
brew tap hcuong-me/tap
brew install zenv
```

### From source

```bash
go install github.com/hcuong-me/zenv/cmd/zenv@latest
```

Or clone and build:

```bash
git clone https://github.com/hcuong-me/zenv.git
cd zenv
go build -o zenv ./cmd/zenv
mv zenv /usr/local/bin/
```

## Setup

Run the doctor command to install the shell hook:

```bash
zenv doctor
```

Then restart your terminal or run:

```bash
source ~/.zshrc
```

## Usage

### Add/update a variable

```bash
zenv set
```

Follow the interactive prompts. Values are entered via TUI (masked) to prevent shell history leaks.

### List variables

```bash
zenv ls
```

Shows all managed variables with masked values.

### Remove a variable

```bash
zenv rm API_KEY
```

### Migrate from .zshrc

Move existing exports from `.zshrc` to `.zshenv`:

```bash
zenv migrate
```

This will:
1. Scan `.zshrc` for `export` statements
2. Let you select which variables to migrate via TUI
3. Create a backup of `.zshrc`
4. Remove migrated exports from `.zshrc`

### Check installation

```bash
zenv doctor
```

Verifies shell hook is installed and `.zshenv` permissions are correct.

## How It Works

zenv stores variables in `~/.zshenv` with file permissions `600` (owner-only access). A shell hook in `.zshrc` overrides the `env` and `printenv` commands to mask values from output while keeping them available to applications.

Example:
```bash
# ~/.zshenv (managed by zenv)
export API_KEY="secret123"

$ env | grep API_KEY
API_KEY=********          # masked in terminal

$ node -e "console.log(process.env.API_KEY)"
secret123                  # real value available to apps
```

## Security

- File permissions: `~/.zshenv` is `600` (owner read/write only)
- No shell history: TUI input prevents values from appearing in `.zsh_history`
- No encryption: relies on filesystem permissions (same as SSH keys)

## Requirements

- macOS
- zsh shell

## License

MIT
