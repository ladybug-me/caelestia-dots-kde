# The installer TUI is the single entry point for install, update, and uninstall

The C++ TUI gained a top-level action screen offering Install, Update, and Uninstall (issue #537 asked for unified installation/removal). Install runs the wizard in-process. Update and Uninstall leave the TUI's raw/alternate screen, run `update.sh` or `uninstall.sh` on the real terminal, then terminate; `setup.sh --update` and `setup.sh --uninstall` skip the menu entirely.

We deliberately kept the existing interactive scripts instead of reimplementing their flows inside the TUI: they own backup selection, package-removal lists, and shell restarts, and they stay runnable standalone. The TUI only fronts them, and both scripts share `scripts/lib/log.sh` with the install step scripts.
