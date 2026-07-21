# Changelog

All notable changes to Lattice Five are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build
number** within it — the version stays steady while the build climbs each
TestFlight upload. Each version's top section, **Unreleased (next build)**,
collects entries merged to `main` but not yet in a TestFlight build; cutting a
release renames it to that build's heading and opens a fresh empty one. A
user-facing PR writes its own bullet here (see [AGENTS.md](AGENTS.md)).

## [Unreleased]

Pre-code: planning docs only. The first code milestone is **v0.1.0 — the
core, playable** (see [ROADMAP.md](ROADMAP.md)).

### Unreleased (next build)

- Project scaffolding: XcodeGen project (iOS + macOS targets, Universal
  Purchase bundle id), `LatticeCore` package with the grid model (points,
  axes, canonical segments, symmetries, the standard 36-dot cross) and its
  tests, a minimal monochrome board render, pinned lint/format tooling, and
  CI (lint, tests + coverage, both platform builds).
