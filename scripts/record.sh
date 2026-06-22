#!/usr/bin/env bash

# Check if gpu-screen-recorder is already recording
if pidof gpu-screen-recorder >/dev/null; then
    caelestia record
    exit 0
fi

ARGS=()
for ((i=1;i<=$#;i++)); do
    if [[ "${!i}" == "--region" ]]; then
        next=$((i+1))
        ARGS+=("-r" "${!next}")
        i=$next
    elif [[ "${!i}" == "--sound" ]]; then
        ARGS+=("-s")
    elif [[ "${!i}" == "--fullscreen" ]]; then
        ARGS+=()
    fi
done

caelestia record "${ARGS[@]}" &