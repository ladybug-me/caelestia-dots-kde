# Installer runs as a single-pane TUI without tmux

The installer used to run the progress UI and the live script log in a tmux split-pane session managed from `setup.sh`: FIFOs (`/tmp/caelestia_cmd`, `/tmp/caelestia_status`), a pane-width cap, and a `CAELESTIA_TMUX_MASTER` self-re-exec. In the 2026-08 redesign it became a single-pane C++ TUI: the TUI spawns each step script itself, appends script output to `install.log`, and a key toggles between the progress list and a live tail of that log.

The tmux wrapper was the source of the long-running flash-and-exit bugs (self-deadlock on the flock guard, pane death on crash, pane-width ballooning) and forced every diagnostic path to be duplicated three ways. A single process owns the terminal, so those classes of bug disappear. The trade-off: progress and logs are no longer visible simultaneously - the log toggle and the persisted `install.log` cover it.
