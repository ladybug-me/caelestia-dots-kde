# Upstream sync

The `shell/` directory is the vendored shell - a fork of the upstream shell
(`caelestia-dots/shell`). This document is the process for keeping the two in
sync.

## Goal

Take upstream improvements wherever they are portable, and keep our KDE
adaptations on top, without ever losing KDE-only work. Upstream is the source
of features; this repo is the KDE port.

## The two anchors

- `upstream` - the git remote pointing at `caelestia-dots/shell`. The source
  of truth.
- `mirror/upstream` - a local branch mirroring `upstream/main`. The snapshot
  the sync tool compares against.

## The sync report

`python tools/sync-shell.py fetch` refreshes both anchors.

`python tools/sync-shell.py report` compares `shell/` against
`upstream/main` and sorts every file into four buckets:

| bucket | meaning | action |
| --- | --- | --- |
| in sync | identical on both sides | nothing |
| kde-only | exists only in `shell/` | never touched by a sync |
| missing | exists only upstream | candidate to bring down |
| diverged | exists in both, different | triage per file |

`--full` shows every diverged file; the default shows the first 60.

## Per-release checklist

Before each release, on a clean branch:

1. `python tools/sync-shell.py fetch`
2. `python tools/sync-shell.py report --full`
3. For every missing file: decide bring down or skip.
4. For every diverged file: decide which side wins. Ask: is our version a KDE
   adaptation, or is it stale against upstream?
5. Bring chosen files with `python tools/sync-shell.py bring <path>...`.
6. Adapt, build, and test. Commit with the upstream commit reference.
7. Never sync repo metadata: `.github`, `nix`, `flake.*`, `README.md`, and
   assets unless a feature needs them.

## Bring and adapt

`bring` copies upstream files into `shell/` verbatim. After bringing, the
real work is adaptation:

- portable QML: usually just resolving imports and page registration.
- Hyprland-coupled QML: add a KWin shim behind the same service interface.
- C++: ported by hand; never brought blindly.

`bring` refuses to overwrite a file that already exists locally unless you
pass `--force`.

## Rules

- kde-only files are ours. A sync must not delete or overwrite them.
- The C++ plugin (`shell/plugin`) is a KDE rewrite; treat upstream C++ as a
  manual port, not an auto-sync.
- Hyprland coupling is concentrated in a small number of services; keep a
  shim there rather than forking whole modules.
