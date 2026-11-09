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
FORCE="${FORCE:-0}"   # FORCE=1 ./setup.sh -> pluginok/temak/Battle.net ujratelepitese (a temak sajat configja akkor is megmarad)
CHANGED=0

# Ne futhasson ket peldany egyszerre
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/steamdeck-setup.lock"
flock -n 9 || { echo "A script mar fut egy masik peldanyban."; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Telepitett plugin mappaja nev alapjan (plugin.json "name" mezo)
plugin_dir_of() {
  sudo grep -l -s "\"name\": *\"$1\"" "$HB"/plugins/*/plugin.json 2>/dev/null | head -1 || true
}

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
  # mar telepitett plugint nem nyulunk hozza (FORCE=1 frissiti)
  if [ "$FORCE" != 1 ] && [ -n "$(plugin_dir_of "$name")" ]; then
    echo "  = $name (mar telepitve, kihagyom)"; continue
  fi
  hash="$(jq -r --arg n "$name" '[.[]|select(.name==$n)][0].versions[0].hash // empty' "$TMP/plugins.json")"
  [ -n "$hash" ] || { warn "Nincs ilyen plugin a store-ban: $name"; continue; }
  curl -fsSL "$STORE_CDN/$hash.zip" -o "$TMP/plugin.zip"
  echo "$hash  $TMP/plugin.zip" | sha256sum -c --quiet - || { warn "Hash hiba: $name"; continue; }
  # elobb ideiglenes helyre csomagolunk ki, hogy hiba eseten ne maradjon felbehagyott plugin
  stage="$(mktemp -d -p "$TMP")"
  unzip -q "$TMP/plugin.zip" -d "$stage"
  dir="$(ls "$stage" | head -1)"
  [ -n "$dir" ] || { warn "Ures zip: $name"; continue; }
  if [ -e "$HB/plugins/$dir" ]; then sudo mv "$HB/plugins/$dir" "$HB/plugins/$dir.bak.$(date +%s)"; fi
  sudo mv "$stage/$dir" "$HB/plugins/$dir"
  CHANGED=1
  echo "  + $name"
done

# --- 3. CSS Loader temak ---------------------------------------------
log "CSS Loader temak telepitese"
sudo mkdir -p "$HB/themes"
for theme in "${THEME_ORDER[@]}"; do
  # a tema mappaja a neve (a theme.json "name" mezoje alapjan keresunk)
  existing="$(sudo grep -l -s "\"name\": *\"$theme\"" "$HB"/themes/*/theme.json 2>/dev/null | head -1 || true)"
  if [ -n "$existing" ] && [ "$FORCE" != 1 ]; then
    echo "  = $theme (mar telepitve, a beallitasaidat nem bantom)"; continue
  fi
  q="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$theme")"
  blob="$(curl -fsSL "$THEME_API/themes?search=$q" | jq -r --arg n "$theme" '[.items[]|select(.name==$n)][0].download.id // empty')"
  [ -n "$blob" ] || { warn "Tema nem talalhato: $theme"; continue; }
  curl -fsSL "$THEME_API/blobs/$blob" -o "$TMP/theme.zip"
  stage="$(mktemp -d -p "$TMP")"
  unzip -q "$TMP/theme.zip" -d "$stage"
  dir="$(ls "$stage" | head -1)"
  [ -n "$dir" ] || { warn "Ures zip: $theme"; continue; }
  # frissiteskor a regi mappa (benne a sajat config) megmarad, csak a tema fajljai cserelodnek
  sudo mkdir -p "$HB/themes/$dir"
  sudo cp -a "$stage/$dir/." "$HB/themes/$dir/"
  # CSS Loader (root-kent fut) ide olvassa a bekapcsolast + beallitasokat – meglevo configot SOSE irunk felul
  if [ ! -e "$HB/themes/$dir/config_ROOT.json" ]; then
    jq -n --argjson v "${THEME_CONFIG[$theme]:-{\}}" '{active:true} + $v' \
      | sudo tee "$HB/themes/$dir/config_ROOT.json" >/dev/null
  fi
  CHANGED=1
  echo "  + $theme"
done

# --- 4. CurseForge ---------------------------------------------------
if [ "$INSTALL_CURSEFORGE" = 1 ]; then
  log "CurseForge (Flatpak)"
  flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  if flatpak info --user com.overwolf.curseforge >/dev/null 2>&1 || flatpak info com.overwolf.curseforge >/dev/null 2>&1; then
    echo "  = CurseForge mar telepitve, kihagyom"
  else
    flatpak install --user -y flathub com.overwolf.curseforge
  fi
fi

# --- 5. Battle.net ---------------------------------------------------
STEAM_COMPAT="$HOME/.local/share/Steam/steamapps/compatdata"
BNET_EXE1="$STEAM_COMPAT/NonSteamLaunchers/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
BNET_EXE2="$STEAM_COMPAT/Battle.netLauncher/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
if [ "$INSTALL_BATTLENET" = 1 ] && { [ -e "$BNET_EXE1" ] || [ -e "$BNET_EXE2" ]; } && [ "$FORCE" != 1 ]; then
  log "Battle.net mar telepitve, kihagyom"
elif [ "$INSTALL_BATTLENET" = 1 ]; then
  log "Battle.net telepitese (NonSteamLaunchers)"
  warn "Ez grafikus telepitot nyit – kovesd a lepeseket; a Steam ujrainditasat kerheti."
  curl -fsSL https://raw.githubusercontent.com/moraroy/NonSteamLaunchers-On-Steam-Deck/main/NonSteamLaunchers.sh \
    | /bin/bash -s -- "Battle.net"
fi

# --- Decky ujrainditas -----------------------------------------------
if [ "$CHANGED" = 1 ]; then
  log "Decky ujrainditasa"
  sudo systemctl restart plugin_loader.service || true
else
  log "Nem valtozott semmi, Decky ujrainditas nem kell"
fi

log "KESZ! Menj vissza Gaming Modera (vagy inditsd ujra a Steamet) – a pluginok es temak aktiv lesznek."
