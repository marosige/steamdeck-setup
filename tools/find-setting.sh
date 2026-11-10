#!/usr/bin/env bash
# Finds which Steam config file/key changes when you toggle a Gaming Mode setting.
#   1) ./tools/find-setting.sh before     (snapshot the current state)
#   2) toggle the setting in Gaming Mode (e.g. 24-hour clock)
#   3) ./tools/find-setting.sh after      (shows what changed)
# If "after" is empty: exit Steam (Desktop Mode: Steam tray icon > Exit Steam) and run it again.
set -euo pipefail
SNAP="${XDG_CACHE_HOME:-$HOME/.cache}/steam-setting-snap"
STEAM="$HOME/.local/share/Steam"
files() {
  ls "$STEAM"/config/config.vdf "$STEAM"/userdata/*/config/localconfig.vdf \
     "$STEAM"/userdata/*/config/sharedconfig.vdf 2>/dev/null || true
  find "$HOME/.config/steamos-manager" "$HOME/.config/steam" -type f 2>/dev/null || true
}
case "${1:-}" in
  before)
    mkdir -p "$SNAP"; find "$SNAP" -type f -delete
    files | while read -r f; do mkdir -p "$SNAP$(dirname "$f")"; cp "$f" "$SNAP$f"; done
    echo "Saved. Now toggle the setting, then run: $0 after" ;;
  after)
    files | while read -r f; do
      if [ -f "$SNAP$f" ]; then diff -u "$SNAP$f" "$f" || true; else echo "NEW FILE: $f"; fi
    done ;;
  *) echo "Usage: $0 before|after"; exit 1 ;;
esac
