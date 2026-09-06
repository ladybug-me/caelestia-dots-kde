# Bubble Tea and gum for terminal UIs

The installer TUI (`caelestia-install`) is rewritten from hand-rolled C++ (raw termios and escape-sequence drawing) to Go with charmbracelet Bubble Tea, and the loose interactive bash prompts in `update.sh`, `uninstall.sh`, `ollama_setup.sh`, and `setup.sh` move to charmbracelet gum. This swaps unmaintainable, untestable drawing code for Bubble Tea's Elm-style model/update/view architecture, makes the UI unit-testable, and reduces the build to a static cross-compile.

## Considered Options

- Keep the C++ TUI. Rejected: the hand-rolled termios and escape-sequence code is hard to change, has no per-PR compile coverage, and needs a two-native-runner release matrix plus a g++/cmake/make compile fallback.
- Rewrite in Go but keep a hand-rolled renderer. Rejected: Bubble Tea's Bubbles and Lip Gloss components and event loop are the point of the port.
- Use gum for everything, including the installer. Rejected: gum is for one-shot shell prompts, not a full-screen wizard with progress, review, and live-log views.

## Consequences

- The installer's data contract (`menu.json`, `theme.json`, step scripts, exit marker) is unchanged; the Go binary is a drop-in replacement.
- The repo gains a Go toolchain dependency: releases cross-compile static binaries, the local compile fallback auto-installs `go`, and dependencies are vendored for offline builds.
- Phases and steps move from `Runner.cpp` to `installer/steps.json` as the single source of truth.
