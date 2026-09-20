# Table of Contents

## Front Matter
- [About this book](./README.md) — thesis, audience, how to read

## Part I — The Problem and the Hard Wall
> *The medium constrains the message — and the shell is a hostile medium for secrets.*

- [Chapter 1 — The Parent–Child Wall](./ch01-parent-child-wall.md)
  - Why a CLI cannot secure a shell secret the naive way
  - How one constraint forces the entire file-plus-sourcing design
- [Chapter 2 — The Threat Model, and the Bet](./ch02-threat-model.md)
  - Naming the thesis; what zenv defends against and what it refuses to
  - The road not taken: why not encrypt at rest
- [Chapter 3 — The Storage Layer](./ch03-storage-layer.md)
  - CRUD on a shell file via regex, treating `~/.zshenv` as a database
  - Atomic writes and the commutativity of escape ordering

## Part II — The Core Bet in Practice
> *Show the map, never the territory.*

- [Chapter 4 — The Masking Hook](./ch04-masking-hook.md)
  - The inversion: load secrets into RAM, then rig the display
  - Line-by-line reading of the masking pipeline
- [Chapter 5 — The Secret Never Typed](./ch05-tui.md)
  - The TUI as a security boundary; masked entry means no argv, no history
  - The road not taken: why there is no `set KEY VALUE` flag form
- [Chapter 6 — The Command Surface](./ch06-command-surface.md)
  - The Cobra layer and the silent-cancel convention
  - Error-wrapping discipline and the `source` reminder as honest UX

## Part III — Operating and Sustaining the System
> *A secret manager is a lifeboat, not a statue — it has to be re-checked.*

- [Chapter 7 — Migration](./ch07-migration.md)
  - The one-way ratchet from `~/.zshrc` to `~/.zshenv`
  - The denylist as judgment, the backup as safety net
- [Chapter 8 — Doctor, and the Honesty Loop](./ch08-doctor.md)
  - Secrets rot; `doctor` is the closed-loop repair
  - Confirm-before-mutate as a UI principle
- [Chapter 9 — Architecture as Invariant](./ch09-architecture.md)
  - The four-layer model and why linting dependency direction matters
  - Why discipline at small scale is the load-bearing wall

## Epilogue
- [Epilogue — Transferable Lessons](./epilogue-transferable-lessons.md)
  - Synthesis across the whole book; the patterns most worth stealing
