#!/usr/bin/env bash
# Live check: Keychain load via ~/.zshrc without writing a home env startup file.
# Never prints secret values.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/dist/zenv"
if [[ ! -x "$BIN" ]]; then
  (cd "$ROOT" && make build)
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/zenv-live.XXXXXX")"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

export HOME="$WORKDIR"
export ZDOTDIR="$WORKDIR"
export ZENV_HOME="$WORKDIR"
export ZENV_SERVICE="me.hcuong.zenv.live.$$"
export ZENV_KEYCHAIN="$WORKDIR/zenv.keychain"
export SHELL="/bin/zsh"
export PATH="$(dirname "$BIN"):$PATH"
touch "$HOME/.zshrc"
: >"$HOME/.zshenv"
ZSHENV_BEFORE="$(cksum "$HOME/.zshenv")"

security create-keychain -p zenv-live "$ZENV_KEYCHAIN" >/dev/null
security set-keychain-settings -t 86400 "$ZENV_KEYCHAIN" >/dev/null
security unlock-keychain -p zenv-live "$ZENV_KEYCHAIN"

"$BIN" put --key LIVECHECK_KEY --value livecheck-secret
for i in $(seq 1 20); do
  "$BIN" put --key "PERFKEY_$i" --value "v$i"
done
"$BIN" doctor --yes >/dev/null
"$BIN" keys | grep -qx LIVECHECK_KEY

if grep -q livecheck-secret "$HOME/.zshrc" || grep -q livecheck-secret "$HOME/.zshenv"; then
  echo "FAIL secret leaked into a file"
  exit 1
fi

MASKED="$(zsh -f -c 'source "$HOME/.zshrc"; printenv LIVECHECK_KEY' 2>/dev/null || true)"
if [[ "$MASKED" != "********" ]]; then
  echo "FAIL printenv after sourcing hook was not masked"
  exit 1
fi

CHILD="$(zsh -f -c 'source "$HOME/.zshrc"; if [ "$LIVECHECK_KEY" = "livecheck-secret" ]; then echo ok; else echo bad; fi')"
if [[ "$CHILD" != "ok" ]]; then
  echo "FAIL child process did not inherit the real value"
  exit 1
fi

EMPTY="$(zsh -f -c 'printenv LIVECHECK_KEY' 2>/dev/null || true)"
if [[ -n "$EMPTY" ]]; then
  echo "FAIL non-interactive zsh received the secret"
  exit 1
fi

ZSHENV_AFTER="$(cksum "$HOME/.zshenv")"
if [[ "$ZSHENV_BEFORE" != "$ZSHENV_AFTER" ]]; then
  echo "FAIL home env startup file was rewritten"
  exit 1
fi
if grep -q LIVECHECK_KEY "$HOME/.zshenv"; then
  echo "FAIL key written to home env startup file"
  exit 1
fi

"$BIN" kc-delete --key LIVECHECK_KEY

export ZENV_BIN="$BIN"
zsh -f -c '
zmodload zsh/datetime
env_times=()
ls_times=()
for i in {1..20}; do
  t0=$EPOCHREALTIME
  "$ZENV_BIN" env >/dev/null
  env_times+=($(( (EPOCHREALTIME - t0) * 1000 )))
  t1=$EPOCHREALTIME
  "$ZENV_BIN" ls >/dev/null
  ls_times+=($(( (EPOCHREALTIME - t1) * 1000 )))
done
env_sorted=(${(n)env_times})
ls_sorted=(${(n)ls_times})
env_p95=$env_sorted[19]
ls_p95=$ls_sorted[19]
print -r -- "zenv env n=20 p95_ms=${env_p95}"
print -r -- "zenv ls n=20 p95_ms=${ls_p95}"
(( env_p95 < 200 )) || { print -r -- "FAIL zenv env P95 exceeded 200 ms"; exit 1 }
(( ls_p95 < 150 )) || { print -r -- "FAIL zenv ls P95 exceeded 150 ms"; exit 1 }
'

echo "PASS live hook: masked printenv, child sees value, zsh -c empty, home env file unchanged, env/ls P95 ok"
