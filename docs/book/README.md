# zenv — A Small System, Defended at the Seams

> A technical book about the architecture, patterns, and internals of zenv.

This book is an O'Reilly-style deep reading of a single, deliberately small system. zenv is a Go CLI that manages secret environment variables for Zsh users. It is small enough to read in an afternoon — a thin binary plus a short shell hook — and yet it contains nearly every hard problem that a local-secret tool has to solve: how a child process cannot mutate its parent, where to defend a secret that must remain usable, how to treat a shell file as a database without corrupting it, how to render a value useless the moment someone glances at the screen.

The source code is short. The book is long, because the source is silent about *why*.

## The thesis, in one sentence

**zenv bets that the right place to defend a local secret is the moment it is *shown*, not the moment it is *saved*.**

Encryption-at-rest guards a file that is sitting still. It does nothing when the user runs `env` during a screen share. zenv inverts the posture — plaintext on disk behind strict file permissions, but every display path rigged to redact. Every subsystem either serves this bet or exists because the shell forces it.

## Who this book is for

Two readers are served simultaneously.

- **The technical lead** wants the architecture and the rationale: why file permissions over encryption, why a shell hook over a custom shell, why every `set` ends with *"run source."* This reader can skip code blocks and deep-dive callouts without losing the thread.
- **The senior Go engineer** wants implementation-level understanding: the atomic write dance (temp file in the same directory, `chmod` before rename), the regex-based CRUD on a shell file, the escape/unescape roundtrip and why the ordering of replacements matters, the `sed` pipeline inside the hook.

## What this book is not

It is not documentation. The reference docs live in `docs/`. It is not a tutorial — you will not be walked through installing zenv. It is a book that teaches how the system works, why each decision was made, and which patterns you can steal for your own tools.

It is also not a reproduction of the source. Code blocks are pseudocode that illustrates patterns. Variable names are generic on purpose. The goal is to make the ideas transferable, not to let a reader reconstruct the binary.

## How to read it

Read Part I straight through — the opening chapters establish a constraint and a threat model that everything else responds to. After that, Parts II and III can be read in order, or dipped into by interest. Each chapter opens with a backward reference so you can enter mid-book without getting lost, and closes with five transferable patterns under **Apply This**.

Mermaid diagrams render natively on GitHub and in most markdown viewers.

## A note on scale

This book was calibrated to the codebase it describes. zenv is small, and a book that padded every chapter to a uniform length would betray the engineer's instinct that small things should be explained economically. Where a chapter is short, it is short because the subsystem is. Where a chapter is long — the masking hook, the storage layer — it is because the ideas there generalize furthest.

## Contents

See [SUMMARY.md](./SUMMARY.md) for the full table of contents.
