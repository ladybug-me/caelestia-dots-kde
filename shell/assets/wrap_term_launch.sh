#!/usr/bin/env sh

cat ~/.local/state/caelestia/sequences.txt 2>/dev/null >/dev/tty || true

exec "$@"
