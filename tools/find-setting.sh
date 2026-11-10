#!/usr/bin/env bash
# Megkeresi, melyik Steam konfigfajlban/kulcsban valtozik egy Gaming Mode beallitas.
#   1) ./tools/find-setting.sh before     (mentes a jelenlegi allapotrol)
#   2) kapcsold at a beallitast Gaming Modeban (pl. 24 hour clock)
#   3) ./tools/find-setting.sh after      (megmutatja, mi valtozott)
# Ha az "after" ures: lepj ki a Steambol (Desktop Mode: Steam ikon > Exit Steam), es futtasd ujra.
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
    echo "Mentve. Most kapcsold at a beallitast, aztan: $0 after" ;;
  after)
    files | while read -r f; do
      if [ -f "$SNAP$f" ]; then diff -u "$SNAP$f" "$f" || true; else echo "UJ FAJL: $f"; fi
    done ;;
  *) echo "Hasznalat: $0 before|after"; exit 1 ;;
esac
