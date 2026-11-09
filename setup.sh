#!/usr/bin/env bash
# Steam Deck automata beallito – factory reset utan futtasd Desktop Modeban:
#   curl -L https://raw.githubusercontent.com/marosige/steamdeck-setup/main/setup.sh | bash
# vagy: git clone ... && ./setup.sh
#
# Amit csinal:
#   1. Decky Loader telepitese
#   2. Decky pluginok (CSS Loader, SteamGridDB) a hivatalos store-bol
#   3. CSS Loader temak (Clean Gameview, Round, Switch Like Home) a kedvenc beallitasaiddal
#   4. CurseForge (Flatpak)
#   5. Battle.net (Proton prefixben, Steam shortcutkent – NonSteamLaunchers)
set -euo pipefail

# ====== BEALLITASOK – ezt szabd testre ==============================
DECKY_PLUGINS=("CSS Loader" "SteamGridDB")

# tema neve -> JSON a beallitasaival (a CSS Loader config formatuma)
declare -A THEME_CONFIG=(
  ["Clean Gameview"]='{"Play Bar Style":"Transparent","Alignment":"Zoom-Center","Show Steam Cloud":"No","Ignore Footer":"No","Lock Logo":"Yes"}'
  ["Round"]='{"Intensity":"10px","Outlines":"Round"}'
  ["Switch Like Home"]='{"No Friends":"Yes","Lift Hero":"0"}'
)
THEME_ORDER=("Clean Gameview" "Round" "Switch Like Home")

INSTALL_CURSEFORGE=1
INSTALL_BATTLENET=1
# ====================================================================

HB="$HOME/homebrew"
STORE_API="https://plugins.deckbrew.xyz/plugins"
STORE_CDN="https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions"
THEME_API="https://api.deckthemes.com"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

need() { command -v "$1" >/dev/null || { echo "Hianyzik: $1"; exit 1; }; }
for c in curl jq unzip python3; do need "$c"; done

# --- sudo jelszo (SteamOS factory reset utan nincs beallitva) --------
if ! passwd -S "$USER" 2>/dev/null | grep -q ' P '; then
  warn "Nincs sudo jelszo beallitva. Allitsd be most:"
  passwd
fi
sudo -v

# --- 1. Decky Loader -------------------------------------------------
if [ ! -d "$HB/services" ]; then
  log "Decky Loader telepitese"
  curl -fsSL https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh
else
  log "Decky Loader mar telepitve, kihagyom"
fi

# --- 2. Decky pluginok -----------------------------------------------
log "Decky pluginok telepitese"
curl -fsSL "$STORE_API" -o "$TMP/plugins.json"
sudo mkdir -p "$HB/plugins"
for name in "${DECKY_PLUGINS[@]}"; do
  hash="$(jq -r --arg n "$name" '[.[]|select(.name==$n)][0].versions[0].hash // empty' "$TMP/plugins.json")"
  [ -n "$hash" ] || { warn "Nincs ilyen plugin a store-ban: $name"; continue; }
  curl -fsSL "$STORE_CDN/$hash.zip" -o "$TMP/plugin.zip"
  echo "$hash  $TMP/plugin.zip" | sha256sum -c --quiet - || { warn "Hash hiba: $name"; continue; }
  dir="$(unzip -Z1 "$TMP/plugin.zip" | head -1 | cut -d/ -f1)"
  sudo rm -rf "$HB/plugins/$dir"
  sudo unzip -qo "$TMP/plugin.zip" -d "$HB/plugins"
  echo "  + $name"
done

# --- 3. CSS Loader temak ---------------------------------------------
log "CSS Loader temak telepitese"
sudo mkdir -p "$HB/themes"
for theme in "${THEME_ORDER[@]}"; do
  q="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$theme")"
  blob="$(curl -fsSL "$THEME_API/themes?search=$q" | jq -r --arg n "$theme" '[.items[]|select(.name==$n)][0].download.id // empty')"
  [ -n "$blob" ] || { warn "Tema nem talalhato: $theme"; continue; }
  curl -fsSL "$THEME_API/blobs/$blob" -o "$TMP/theme.zip"
  dir="$(unzip -Z1 "$TMP/theme.zip" | head -1 | cut -d/ -f1)"
  sudo rm -rf "$HB/themes/$dir"
  sudo unzip -qo "$TMP/theme.zip" -d "$HB/themes"
  # CSS Loader (root-kent fut) ide olvassa a bekapcsolast + beallitasokat
  jq -n --argjson v "${THEME_CONFIG[$theme]:-{\}}" '{active:true} + $v' \
    | sudo tee "$HB/themes/$dir/config_ROOT.json" >/dev/null
  echo "  + $theme"
done

# --- 4. CurseForge ---------------------------------------------------
if [ "$INSTALL_CURSEFORGE" = 1 ]; then
  log "CurseForge (Flatpak) telepitese"
  flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak install --user -y flathub com.overwolf.curseforge
fi

# --- 5. Battle.net ---------------------------------------------------
if [ "$INSTALL_BATTLENET" = 1 ]; then
  log "Battle.net telepitese (NonSteamLaunchers)"
  warn "Ez grafikus telepitot nyit – kovesd a lepeseket; a Steam ujrainditasat kerheti."
  curl -fsSL https://raw.githubusercontent.com/moraroy/NonSteamLaunchers-On-Steam-Deck/main/NonSteamLaunchers.sh \
    | /bin/bash -s -- "Battle.net"
fi

# --- Decky ujrainditas -----------------------------------------------
log "Decky ujrainditasa"
sudo systemctl restart plugin_loader.service || true

log "KESZ! Menj vissza Gaming Modera (vagy inditsd ujra a Steamet) – a pluginok es temak aktiv lesznek."
