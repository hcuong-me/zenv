# zenv

Secure environment variable manager for macOS Zsh. Secrets live in the login Keychain. Interactive shells load them from `~/.zshrc`.

## Features

- **No shell history leaks.** Masked prompts keep values out of `.zsh_history`.
- **Masked display.** `env` and `printenv` show `********`.
- **Apps still get real values.** Child processes inherit the real environment.
- **Keychain storage.** Generic passwords under service `me.hcuong.zenv`.
- **Migration.** Move `export` lines from `~/.zshrc` into Keychain.

## Installation

### Homebrew (recommended)

```bash
brew tap hcuong-me/tap
brew install zenv
```

### From source

```bash
git clone https://github.com/hcuong-me/zenv.git
cd zenv
make build
cp dist/zenv /usr/local/bin/
```

Needs Swift 6 and macOS 13+.

## Setup

```bash
zenv doctor
source ~/.zshrc
```

`doctor --yes` installs the hook without a prompt.

## Usage

```bash
zenv set
zenv ls
zenv rm API_KEY
zenv migrate
zenv doctor
zenv version
zenv -v
```

After `set` or `migrate`, run `source ~/.zshrc` or open a new terminal. Non-interactive `zsh -c` does not load secrets. Run `eval "$(zenv env)"` in a script if you need them there.

## How it works

`zenv set` writes a Keychain item. The `~/.zshrc` hook runs `eval "$(zenv env)"`, then overrides `env` and `printenv`.

```bash
$ env | grep API_KEY
API_KEY=********

$ node -e "console.log(process.env.API_KEY)"
secret123
```

## Security

- At rest, macOS Keychain encrypts the item.
- Display masking is still required. Once exported, RAM holds plaintext.
- Code running as your user can still read items `zenv` can read.
- Linux is unsupported.

## Requirements

- macOS
- zsh

## License

MIT
