# Swift Keychain port plan

Interactive macOS Zsh users keep `zenv set`, `ls`, `rm`, `doctor`, and `migrate`. Secrets move from `~/.zshenv` into the login keychain. Load happens only in `~/.zshrc` through `eval "$(zenv env)"`. Linux and Door 3 go away. The stack is `swift-store`, `swift-hook`, `swift-cli`, then `swift-retire`. The operator lands the chain.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

The program runs `pstack/skills/poteto-mode/playbooks/autopilot-stack.md`. The operator merges `swift-store`, `swift-hook`, `swift-cli`, and `swift-retire` after each STACK-READY verdict. Owners stop at merge-ready.

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

## Program checklist

### Arm the program

- [ ] State the protocol and this plan to the operator, then stop. Start execution only on the operator's explicit go.
- [ ] On the operator's go, arm a `/goal` with this exact text. "`thoughts/shared/plans/2026-09-20-swift-keychain-port.md`. PR ids in order are swift-store, swift-hook, swift-cli, swift-retire. Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. The operator merges. Done when Go is gone, Keychain is the store, and `~/.zshrc` loads secrets without writing `~/.zshenv`."
- [ ] Read these from trunk at program start. Re-read them at every tick.
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/autopilot-stack.md`
  - [ ] `git show origin/main:pstack/skills/swarm/SKILL.md`
  - [ ] `git show origin/main:pstack/skills/control-cli/SKILL.md`
  - [ ] `git show origin/main:pstack/skills/poteto-mode/playbooks/opening-a-pr.md`
  - [ ] `git show origin/main:pstack/skills/how/SKILL.md`
  - [ ] `git show origin/main:pstack/skills/unslop/SKILL.md`
  - [ ] `git show origin/main:pstack/skills/technical-writing/SKILL.md`
- [ ] Arm the 30-minute audit tick. In a local session, a real terminal `/loop`. In a cloud root, a cloud-sleeper wake chain. Never leave the cadence to memory.
- [ ] Use this tick prompt, verbatim. "Re-read the execution playbook from trunk and the armed /goal. Audit the operation against both and fix drift in this tick. Probe every active lane and judge progress by side effects only. Stand down a stuck lane and dispatch its replacement now. Then post a status message to the operator in chat, whether or not anything changed, with the queue table of PR, owner, state, and head SHA, the verdicts since the last tick, what merged, open operator gates, and blockers."
- [ ] On the operator's hold or stand-down, send every owner a zero-writes order at once.

### Spawn owners

- [ ] Spawn one owner per PR with the full lifecycle the execution playbook names.
- [ ] Follow this dependency graph. Start dependent work only after its parent merges, or base it on the parent branch when the execution playbook stacks.
  - [ ] `swift-store` is first and branches from `main`.
  - [ ] `swift-hook` after `swift-store`.
  - [ ] `swift-cli` after `swift-hook`.
  - [ ] `swift-retire` after `swift-cli`.
- [ ] Hold the file boundaries. `swift-store` touches only `Package.swift`, `Sources/ZenvCore/**`, `Sources/zenv/**`, `Tests/**`, and `.gitignore`. `swift-hook` touches only Swift hook and doctor files plus tests. `swift-cli` touches only command and TUI Swift files plus tests. `swift-retire` deletes Go, rewrites docs and CI, and updates Homebrew notes.
- [ ] Hold the review gate. `swift-hook` and `swift-cli` change an interaction. They wait for the operator's review in chat with screenshots and a video before merge.

### PR mechanics, for every PR

- [ ] Resolve the forge once. Default to `gh`; if `command -v origin` succeeds and Origin can resolve the repository, use `origin pr` for every PR operation. Record any fallback to `gh`. Never require `gt`.
- [ ] Open the PR ready, never draft, with `origin pr create --status open --base <base-branch>` or `gh pr create --base <base-branch>` according to the resolved forge. A stack child targets its parent branch.
- [ ] Run the repo's lint and typecheck once before the PR-facing push. Push with hooks on.
- [ ] Run `/deslop` before each commit and `/no-comments` before review.
- [ ] Triage every Bugbot and security-reviewer comment per `../references/bugbot-triage.md`.
- [ ] Rebase onto current trunk before babysit and again before the merge-ready report.

### Verdict and merge, for every PR

- [ ] At the merge-ready head SHA, run the swarm per `pstack/skills/swarm/SKILL.md`. One gates lane. The ten live lanes from the PR's **Verify, live** block. The perf lane from its **Verify, perf** block. One audit lane that reads the diff and the receipts and distrusts the PR body.
- [ ] Clean only when every lane is `PASS`. Findings go back to the owner. A new head gets a fresh swarm and a fresh verdict.
- [ ] The owner reports STACK-READY. The root appends the PR to the base-branch stack. The operator lands bottom-up. After rebase, compare `git patch-id` for each PR's base-to-head diff at its verdict SHA against its new base-to-head diff. Unchanged patch-id keeps the code verdict. Changed patch repeats swarm.

### Boot recipe, for every live lane

Each live lane runs on its own cloud VM at the PR head. Drive through `control-cli` from `cursor-team-kit` when that skill is present. If it is missing, drive `zsh` in Terminal with scripted stdin and capture the pane.

- [ ] `git fetch origin <head-branch> && git checkout <head SHA>`.
- [ ] Build with `swift build -c release`. Wait until `.build/release/zenv` exists. Do not start a server.
- [ ] Deliver input only through the control skill's commands, or through `script` recording of `zsh -i` / `zsh -c`. Name the read-only diagnostics as `security find-generic-password` only for items with service `dev.hcuong.zenv` created by the lane, plus `printenv` after load.
- [ ] Save every screenshot to `/tmp/swarm-<pr-id>/worker-<n>/<slug>.png` and return the paths with the report.

## Add the Keychain store (swift-store)

**Depends on.** None.

**Files.**

- [ ] Create `Package.swift`.
- [ ] Create `Sources/ZenvCore/KeychainStore.swift`.
- [ ] Create `Sources/ZenvCore/ExportRenderer.swift`.
- [ ] Create `Sources/zenv/Zenv.swift`.
- [ ] Create `Tests/ZenvCoreTests/ExportRendererTests.swift`.
- [ ] Create `Tests/ZenvCoreTests/KeychainStoreTests.swift`.
- [ ] Edit `.gitignore`.

**Build.**

- [ ] Add `KeychainStore` with service `dev.hcuong.zenv`, account equal to the uppercase key, `kSecClassGenericPassword`, `kSecAttrSynchronizable` false, and login-keychain access. Implement `put`, `get`, `delete`, `listKeys`, and `exportAll`. Add `ExportRenderer` that emits `export KEY="value"` with the same escapes as `escapeValue` in `internal/storage/zshenv.go`. Add ArgumentParser commands `env`, `keys`, and hidden `put` for tests. Do not install a zsh hook. Leave the Go binary in the tree.

**You see.**

- [ ] `swift run zenv env` prints one `export` line per stored key and never prints a value to stderr. `swift run zenv keys` prints keys only.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `ExportRendererTests` asserts escaped quotes, dollars, backslashes, and backticks against literal expected strings. `KeychainStoreTests` uses a unique service suffix in tests so it never touches user items. Run `swift test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run `zenv version` on trunk Go and `swift run zenv --help` on head. Trunk lacks Keychain. Gate that head help lists `env` and `keys` and that trunk still writes `~/.zshenv` if `zenv set` is used. Save `store-l1-trunk-help.png`. Pass when head help includes `env` and trunk help does not.
- [ ] Lane 2. Hidden `put` then `keys`. Save `store-l2-keys.png`. Pass when stdout is the uppercase key alone.
- [ ] Lane 3. `put` then `env`. Save `store-l3-env.png`. Pass when stdout is a single `export KEY="value"` line and the value matches.
- [ ] Lane 4. Update the same key. Save `store-l4-update.png`. Pass when `env` shows the new value only.
- [ ] Lane 5. Delete the key. Save `store-l5-delete.png`. Pass when `keys` is empty.
- [ ] Lane 6. Empty store. Save `store-l6-empty.png`. Pass when `env` prints nothing and exits 0.
- [ ] Lane 7. Value with `$` and quotes. Save `store-l7-escape.png`. Pass when `eval` of `env` output in zsh yields the original string.
- [ ] Lane 8. Key lowercased on put. Save `store-l8-upper.png`. Pass when stored account is uppercase.
- [ ] Lane 9. Allow the Keychain ACL dialog if it appears, then retry `env`. Save `store-l9-acl.png`. Pass when `env` succeeds after Allow, or when no dialog appears and `env` still succeeds.
- [ ] Lane 10. Confirm `~/.zshenv` is not created or rewritten. Save `store-l10-no-zshenv.png`. Pass when the file mtime is unchanged or the file is absent.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Wall time of `zenv env` for 20 keys on head. Wall time of sourcing a 20-line `~/.zshenv` on trunk. Also isolate head process spawn plus `SecItemCopyMatching`.
- [ ] Probe. Interleave trunk `zsh -c 'source testdata/twenty.zshenv'` and head `swift run -c release zenv env` twenty times after warmup. Both sides print a duration line.
- [ ] Baseline. Record the trunk source duration first.
- [ ] Rule. Head `zenv env` P95 must stay under 200 ms for 20 keys. Do not ratio unlike scenarios. Fail the PR if P95 exceeds 200 ms.

**Review gate.** None. `swift-store` is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends this PR to the base-branch stack. The operator lands it.

## Install the zshrc loader (swift-hook)

**Depends on.** `swift-store`.

**Files.**

- [ ] Create `Sources/ZenvCore/Hook.swift`.
- [ ] Edit `Sources/zenv/Zenv.swift`.
- [ ] Create `Tests/ZenvCoreTests/HookTests.swift`.

**Build.**

- [ ] Add `doctor` that requires Zsh, requires `~/.zshrc`, and installs a marker block `# --- zenv safe display start ---` whose body runs `eval "$(command zenv env)"`, sets `_ZENV_KEYS` from `command zenv keys` joined by `|`, and keeps `_zenv_masker` plus `env`/`printenv` overrides from `internal/shell/zshrc.go` without sourcing `~/.zshenv`. Idempotent install. Backup `~/.zshrc` under `~/.zenv/backups/` as today. If `~/.zshenv` contains `export` lines zenv used to own, prompt to import them through `KeychainStore.put` and then delete only those lines. Leave unrelated `~/.zshenv` content.

**You see.**

- [ ] After `zenv doctor` and a new interactive zsh, `printenv KEY` shows `********` for a managed key and `python3 -c 'import os; print(os.environ["KEY"])'` prints the real value.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `HookTests` asserts the hook string contains `zenv env`, contains `_zenv_masker`, and does not contain `.zshenv`. Run `swift test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Compare trunk hook (sources `~/.zshenv`) with head hook. Trunk lacks Keychain load. Gate that a fresh interactive zsh at head exports a key stored only in Keychain. Save `hook-l1-regression.png`. Pass when head interactive `printenv KEY` is masked and `zsh -c 'printenv KEY'` is empty.
- [ ] Lane 2. `doctor` on a missing `~/.zshrc`. Save `hook-l2-no-zshrc.png`. Pass when the command errors and writes nothing.
- [ ] Lane 3. `doctor` installs the hook once. Save `hook-l3-install.png`. Pass when the marker appears exactly once.
- [ ] Lane 4. `doctor` a second time. Save `hook-l4-idempotent.png`. Pass when the file does not duplicate the block.
- [ ] Lane 5. Interactive `env` masks the value. Save `hook-l5-mask.png`. Pass when the line is `KEY=********`.
- [ ] Lane 6. Child process reads the real value. Save `hook-l6-child.png`. Pass when the child stdout is the secret.
- [ ] Lane 7. `zsh -c` without rc. Save `hook-l7-noninteractive.png`. Pass when the key is unset.
- [ ] Lane 8. Import old `~/.zshenv` exports then strip those lines. Save `hook-l8-import.png`. Pass when Keychain has the keys and the stripped lines are gone, and non-zenv lines remain.
- [ ] Lane 9. `zenv env` failure does not kill the shell. Save `hook-l9-fail-closed.png`. Pass when a broken `zenv` on PATH still yields a prompt and `env` works unmasked.
- [ ] Lane 10. Backup exists under `~/.zenv/backups/`. Save `hook-l10-backup.png`. Pass when a new backup file is present after first install.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Interactive zsh startup to first prompt with 20 keys. Trunk sources `~/.zshenv`. Head runs `eval "$(zenv env)"`. Also isolate head `zenv env` time.
- [ ] Probe. Interleave `zsh -lic 'print -r -- $SECONDS'` on trunk and head twenty times. Both sides print a duration.
- [ ] Baseline. Record trunk startup first.
- [ ] Rule. Head added work (`zenv env` plus eval) P95 must stay under 250 ms. Fail if interactive startup exceeds trunk by more than 400 ms or if the added work exceeds 250 ms.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 5 screenshots into `media/swift-hook-review-mask.png`.
- [ ] Record a 30 to 60 second video of the change on a lane VM. Save it as `media/swift-hook-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends this PR to the base-branch stack. The operator lands it.

## Port the command TUI (swift-cli)

**Depends on.** `swift-hook`.

**Files.**

- [ ] Create `Sources/ZenvCore/TUI.swift`.
- [ ] Edit `Sources/zenv/Zenv.swift`.
- [ ] Create `Sources/ZenvCore/Migrate.swift`.
- [ ] Create `Tests/ZenvCoreTests/MigrateTests.swift`.

**Build.**

- [ ] Port `set` as a two-step masked form matching `internal/tui/form.go` (key then password value, cancel is silent). Port `ls` as a table of keys with `********`. Port `rm KEY`. Port `migrate` from `~/.zshrc` exports into Keychain with the PATH skip heuristics in `internal/shell/zshrc.go`, multi-select confirm, and backup. Print `source ~/.zshrc` after `set` and `migrate`. Do not mention `~/.zshenv` except in the one-time import path already in `doctor`.

**You see.**

- [ ] `zenv set` never puts the value on argv. `zenv ls` shows `********`. `zenv rm KEY` deletes the Keychain item.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `MigrateTests` covers PATH skip, suffix `_PATH` skip, and a real secret selected for import. Run `swift test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run trunk `zenv ls` against `~/.zshenv` and head `zenv ls` against Keychain. Trunk lacks Keychain `ls`. Gate head `ls` after `put` shows the key masked. Save `cli-l1-ls.png`. Pass when the table contains the key and `********`.
- [ ] Lane 2. `set` cancel. Save `cli-l2-cancel.png`. Pass when exit 0 and Keychain unchanged.
- [ ] Lane 3. `set` empty value. Save `cli-l3-empty.png`. Pass when the command errors and stores nothing.
- [ ] Lane 4. `set` add then reminder mentions `~/.zshrc`. Save `cli-l4-set.png`. Pass when stdout contains `source ~/.zshrc` and does not contain `~/.zshenv`.
- [ ] Lane 5. `set` update existing key. Save `cli-l5-update.png`. Pass when stdout contains `Updated`.
- [ ] Lane 6. `rm` missing key. Save `cli-l6-rm-missing.png`. Pass when the command errors.
- [ ] Lane 7. `rm` existing key. Save `cli-l7-rm.png`. Pass when `keys` no longer lists it.
- [ ] Lane 8. `migrate` with only `PATH`. Save `cli-l8-skip-path.png`. Pass when PATH stays in `~/.zshrc` and Keychain is empty of PATH.
- [ ] Lane 9. `migrate` a secret export. Save `cli-l9-migrate.png`. Pass when the export leaves `~/.zshrc` and Keychain has the key.
- [ ] Lane 10. Value never appears in `~/.zsh_history` after `set`. Save `cli-l10-history.png`. Pass when history has `zenv set` or nothing, never the secret.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Time to `zenv ls` with 20 keys. Trunk reads `~/.zshenv`. Head lists Keychain attributes without returning secret data. Also isolate head `SecItemCopyMatching` attributes-only call.
- [ ] Probe. Interleave trunk `zenv ls` and head `zenv ls` twenty times. Both sides print a duration.
- [ ] Baseline. Record trunk `zenv ls` first.
- [ ] Rule. Head `ls` P95 must stay under 150 ms. Fail if attributes-only lookup exceeds 100 ms P95.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 4 screenshots into `media/swift-cli-review-set.png`.
- [ ] Record a 30 to 60 second video of the change on a lane VM. Save it as `media/swift-cli-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends this PR to the base-branch stack. The operator lands it.

## Retire Go and docs (swift-retire)

**Depends on.** `swift-cli`.

**Files.**

- [ ] Delete `cmd/`.
- [ ] Delete `internal/`.
- [ ] Delete `go.mod`.
- [ ] Delete `go.sum`.
- [ ] Edit `Makefile`.
- [ ] Edit `.github/workflows/ci.yml`.
- [ ] Edit `.github/workflows/release.yml`.
- [ ] Edit `README.md`.
- [ ] Edit `AGENTS.md`.
- [ ] Edit `docs/ARCHITECTURE.md`.
- [ ] Edit `docs/PRODUCT_SENSE.md`.
- [ ] Edit `docs/DEVELOPMENT.md`.
- [ ] Edit `docs/book/ch01-parent-child-wall.md`.
- [ ] Edit `docs/book/ch02-threat-model.md`.
- [ ] Edit `docs/book/ch03-storage-layer.md`.
- [ ] Edit `docs/book/ch04-masking-hook.md`.
- [ ] Edit `docs/book/ch06-command-surface.md`.
- [ ] Edit `docs/book/ch07-migration.md`.
- [ ] Edit `docs/book/ch08-doctor.md`.
- [ ] Edit `scripts/lint-deps.sh`.

**Build.**

- [ ] Remove the Go module. Point `make build` at `swift build -c release` and copy `.build/release/zenv` to `dist/zenv`. Run CI only on `macos-latest` with `swift test` and `swift build`. Rewrite docs so the store is Keychain, load is `~/.zshrc`, Linux is unsupported, and the threat model owns file-only theft for zenv-managed secrets. Drop architecture invariants about 0600 writes. Keep the display-masking thesis.

**You see.**

- [ ] `ls cmd` fails. `make build` produces `dist/zenv` as a Mach-O binary. README install no longer says `go install`.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `scripts/lint-deps.sh` either is deleted or checks Swift package layers (`ZenvCore` must not import ArgumentParser UI types if that split exists). Run `make lint-arch` or the replacement script.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `grok-4.6-fast-xhigh` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Trunk `go build` still works. Head has no `go.mod`. Gate that `make build` on head produces `dist/zenv` and `file dist/zenv` reports Mach-O. Save `retire-l1-macho.png`. Pass when Go sources are absent and the Swift binary runs `zenv version`.
- [ ] Lane 2. `make test` runs `swift test`. Save `retire-l2-test.png`. Pass when the suite exits 0.
- [ ] Lane 3. README has no `go install` and no `~/.zshenv` store claim. Save `retire-l3-readme.png`. Pass when a search for `go install` returns none.
- [ ] Lane 4. `AGENTS.md` layer table matches Swift packages. Save `retire-l4-agents.png`. Pass when `internal/storage` is not named as live code.
- [ ] Lane 5. CI workflow has no ubuntu Go lint job. Save `retire-l5-ci.png`. Pass when `.github/workflows/ci.yml` uses `macos-latest` and `swift`.
- [ ] Lane 6. Fresh clone build from README. Save `retire-l6-from-source.png`. Pass when the documented commands produce a working `zenv`.
- [ ] Lane 7. `zenv doctor` still installs the Swift hook. Save `retire-l7-doctor.png`. Pass when the marker exists.
- [ ] Lane 8. Book ch01 no longer says Door 3 through `~/.zshenv`. Save `retire-l8-book.png`. Pass when ch01 describes Door 2 `eval "$(zenv env)"`.
- [ ] Lane 9. Product sense target user is macOS only. Save `retire-l9-product.png`. Pass when Linux is a non-goal.
- [ ] Lane 10. Release workflow builds Swift. Save `retire-l10-release.png`. Pass when `release.yml` invokes `swift build`.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. `make build` wall time on trunk (`go build`) and head (`swift build -c release`). Also isolate head link time of `zenv`.
- [ ] Probe. Interleave `make clean && make build` on trunk and head three times. Both sides print a duration.
- [ ] Baseline. Record trunk `go build` first.
- [ ] Rule. Head release build may be slower than Go. Fail only if a clean `swift build -c release` exceeds 120 s on macos-latest class hardware.

**Review gate.** None. `swift-retire` is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends this PR to the base-branch stack. The operator lands it.

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] Reply to the operator with the report the execution playbook names.

## Appendix A. Prototype evidence

No prototype branch was cut in this planning session. Auto-review blocked a live `security add-generic-password` probe. Named-model explorers failed on the free plan. Unproven items are login-keychain ACL from an unsigned Swift binary, `zenv env` P95 versus the 200 ms budget, and whether a huh-level TUI is reachable in Swift without a new dependency. `swift-store` is the proving PR. If lane 9 cannot store without a signed binary, stop the stack and add a codesign step before `swift-hook`.

## Appendix B. Alternatives rejected

Keep Go and call Security.framework. Rejected because the operator asked for a Swift port.

Write plaintext `export` lines to `~/.zshenv` after each Keychain put. Rejected because the operator forbade using `~/.zshenv` and that would keep secrets on disk.

Load from `~/.zshenv` with `eval "$(zenv env)"` so every shell gets secrets. Rejected because Keychain I/O in non-interactive shells fails silent and slows `zsh -c`. Load stays in `~/.zshrc`.

Data Protection keychain plus access groups in v1. Rejected until codesign exists. v1 uses the login keychain.

huh via a Go helper beside Swift. Rejected. Two binaries split the product.

## Appendix C. Risks

Unsigned CLI ACL prompts land in `swift-store`. Watch lane 9.

SSH and non-GUI sessions land in `swift-hook`. Watch lane 7. Document empty env as expected.

`zenv env` prints secrets to stdout. A user who runs it while sharing a screen leaks. Keep it out of the default help examples. Prefer `keys` in docs.

This repo's `origin/main` does not contain `pstack/skills`. Arm boxes that `git show` those paths will fail until the operator points at the skill tree on disk. Use `/Users/greennext/.claude/skills/poteto-mode/playbooks/autopilot-stack.md` as the real playbook.

`control-cli` from `cursor-team-kit` was not found in this workspace. Live lanes fall back to scripted `zsh`. That is a surface-control gap.

Homebrew tap still builds Go until `swift-retire`. Users who `brew upgrade` mid-stack get a mixed world. Do not publish the tap until `swift-retire` lands.

## Appendix D. Links and reading list

Read `internal/storage/zshenv.go`, `internal/shell/zshrc.go` (`getHookContent`, migrate heuristics), `internal/tui/form.go`, `cmd/commands/*.go`, `docs/book/ch01-parent-child-wall.md`, `docs/book/ch02-threat-model.md`, `docs/PRODUCT_SENSE.md`.

Run `how` before `swift-hook` (zsh load order) and `swift-cli` (TUI cancel paths). Run `interrogate` before review of `swift-hook` and `swift-cli`. Keep a local `decisions.tsv` per `show-me-your-work`. Do not commit the trail.

Apple Keychain add API. [Adding a password to the keychain](https://developer.apple.com/documentation/security/adding-a-password-to-the-keychain).

CLI Keychain signing note. [Swift Keychain Services Guide](https://swiftcrafted.dev/article/swift-keychain-services-secure-storage-ios-26).
