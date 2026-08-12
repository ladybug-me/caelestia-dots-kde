            `saveFile="$SAVE_DIR/screenshot-$(date +%Y-%m-%d_%H.%M.%S).png" && ` +
                    `${cropBase} "$saveFile" && ` +
                    `wl-copy -t image/png < "$saveFile"; ` +
                    `ACTION=$(notify-send --wait "Screenshot Captured" "Saved to $saveFile" -i "$saveFile" -a "Screenshot" --action="open=Open" --action="folder=Open Folder" || true); ` +
                    `if [ "$ACTION" = "open" ]; then xdg-open "$saveFile"; elif [ "$ACTION" = "folder" ]; then xdg-open "$SAVE_DIR"; fi; ` +
                    `${cleanup}`
                ]
            }

            case ScreenshotAction.Action.Edit: {
                let saveDir = rawSaveDir === "" ? "~/Pictures/Screenshots" : rawSaveDir;
                return ["bash", "-c",
                    `set -euo pipefail; ` +
                    `SAVE_DIR='${escapeShellStr(saveDir)}'; ` +
                    `SAVE_DIR="${SAVE_DIR/#\\~/$HOME}"; ` +
                    `mkdir -p "$SAVE_DIR" && ` +
                    `saveFile="$SAVE_DIR/screenshot-$(date +%Y-%m-%d_%H.%M.%S).png" && ` +
                    `TMPF=$(mktemp /tmp/qs-snip-XXXXXX.png); ` +
                    `${cropBase} "$TMPF" && ` +
                    `CONF_DIR=$(mktemp -d); ln -s ~/.config/* "$CONF_DIR/" 2>/dev/null || true; rm -rf "$CONF_DIR/swappy"; mkdir -p "$CONF_DIR/swappy"; ` +
                    `SWAPPY_OUT_DIR=$(mktemp -d /tmp/swappy-out-XXXXXX); ` +
                    `if [ -f ~/.config/swappy/config ]; then cp ~/.config/swappy/config "$CONF_DIR/swappy/config"; else echo "[Default]" > "$CONF_DIR/swappy/config"; fi; ` +
                    `sed -i '/^early_exit.*/d; /^save_dir.*/d; /^save_filename_format.*/d; /^auto_save.*/d' "$CONF_DIR/swappy/config"; ` +
                    `echo -e "early_exit=true\\nsave_dir=$SWAPPY_OUT_DIR\\nsave_filename_format=swappy-out.png\\nauto_save=true" >> "$CONF_DIR/swappy/config"; ` +
                    `XDG_CONFIG_HOME="$CONF_DIR" ${annotationCommand} -f "$TMPF" -o "$saveFile" || true; ` +
                    `rm -rf "$CONF_DIR"; ` +
                    `if [ ! -s "$saveFile" ]; then ` +
                        `OUT_FILE=$(ls "$SWAPPY_OUT_DIR"/*.png 2>/dev/null | head -n 1); ` +
                        `if [ -n "$OUT_FILE" ]; then mv "$OUT_FILE" "$saveFile"; fi; ` +
                    `fi; ` +
                    `rm -rf "$SWAPPY_OUT_DIR"; ` +
                    `if [ -s "$saveFile" ]; then ` +
                        `wl-copy -t image/png < "$saveFile"; ` +
                        `ACTION=$(notify-send --wait "Screenshot Captured" "Saved to $saveFile" -i "$saveFile" -a "Screenshot" --action="open=Open" --action="folder=Open Folder" || true); ` +
                        `if [ "$ACTION" = "open" ]; then xdg-open "$saveFile"; elif [ "$ACTION" = "folder" ]; then xdg-open "$SAVE_DIR"; fi; ` +
