#!/usr/bin/env bash
# Steam Deck setup script. Run it in Desktop Mode after a factory reset:
#   curl -fsSL https://raw.githubusercontent.com/marosige/steamdeck-setup/main/setup.sh | bash
# or: git clone https://github.com/marosige/steamdeck-setup && ./steamdeck-setup/setup.sh
#
# What it does:
#   1. Installs Decky Loader
#   2. Installs Decky plugins (CSS Loader, SteamGridDB) from the official store
#   3. Installs CSS Loader themes (Clean Gameview, Round, Switch Like Home) with preset settings
#   4. Installs CurseForge (Flatpak)
#   5. Installs Battle.net (Proton prefix + Steam shortcut, via NonSteamLaunchers)
#   6. Sets the battery charge limit
set -euo pipefail

# ====== SETTINGS - customize here ====================================
DECKY_PLUGINS=("CSS Loader" "SteamGridDB")

# theme name -> JSON with its settings (CSS Loader config format)
declare -A THEME_CONFIG=(
  ["Clean Gameview"]='{"Play Bar Style":"Transparent","Alignment":"Zoom-Center","Show Steam Cloud":"No","Ignore Footer":"No","Lock Logo":"Yes"}'
  ["Round"]='{"Intensity":"10px","Outlines":"Round"}'
  ["Switch Like Home"]='{"No Friends":"Yes","Lift Hero":"0"}'
)
THEME_ORDER=("Clean Gameview" "Round" "Switch Like Home")

INSTALL_CURSEFORGE=1
INSTALL_BATTLENET=1

# Battery charge limit in percent, 0 = don't touch
CHARGE_LIMIT=80
# =====================================================================

HB="$HOME/homebrew"
STORE_API="https://plugins.deckbrew.xyz/plugins"
STORE_CDN="https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions"
THEME_API="https://api.deckthemes.com"
FORCE="${FORCE:-0}"   # FORCE=1 reinstalls plugins/themes/Battle.net (theme settings are still kept)
CHANGED=0

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }
need() { command -v "$1" >/dev/null || { echo "Missing required tool: $1"; exit 1; }; }

# Directory of an installed Decky plugin, found by the "name" in its plugin.json
plugin_dir_of() {
  sudo grep -l -s "\"name\": *\"$1\"" "$HB"/plugins/*/plugin.json 2>/dev/null | head -1 || true
}

# Write the enabled flag + settings for a theme. CSS Loader reads config_ROOT.json or
# config_USER.json depending on which user it runs as, so write both.
# An existing config is NEVER overwritten.
ensure_theme_config() {
  local dir="$1" theme="$2" suffix
  for suffix in ROOT USER; do
    if [ ! -e "$HB/themes/$dir/config_$suffix.json" ]; then
      jq -n --argjson v "${THEME_CONFIG[$theme]:-{\}}" '{active:true} + $v' \
        | sudo tee "$HB/themes/$dir/config_$suffix.json" >/dev/null
      CHANGED=1
    fi
  done
}

# Helper for adding non-Steam shortcuts: use the local copy if run from a clone,
# otherwise download it (when run via `curl | bash`).
shortcut_tool() {
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
  if [ -f "$here/tools/add_shortcut.py" ]; then
    python3 -I "$here/tools/add_shortcut.py" "$@"
  else
    curl -fsSL https://raw.githubusercontent.com/marosige/steamdeck-setup/main/tools/add_shortcut.py -o "$TMP/add_shortcut.py"
    python3 -I "$TMP/add_shortcut.py" "$@"
  fi
}
has_shortcut() { shortcut_tool --has "$1" >/dev/null 2>&1; }

# Steam rewrites shortcuts.vdf while it runs, so it has to be closed to edit it.
STEAM_WAS_RUNNING=0
stop_steam() {
  if pgrep -x steam >/dev/null; then
    STEAM_WAS_RUNNING=1
    echo "  closing Steam for a moment..."
    steam -shutdown >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do pgrep -x steam >/dev/null || break; sleep 1; done
    pkill -x steam 2>/dev/null || true
  fi
}
start_steam() {
  if [ "$STEAM_WAS_RUNNING" = 1 ]; then
    echo "  starting Steam again..."
    nohup steam -silent >/dev/null 2>&1 &
    STEAM_WAS_RUNNING=0
  fi
}

# Everything lives in main() so bash parses the whole script before running it.
# That matters for `curl | bash`: there bash reads the script from stdin, and
# anything that reads stdin (like passwd) would otherwise swallow the script.
main() {
  # Take interactive input from the terminal, not from the pipe
  if [ -r /dev/tty ]; then exec </dev/tty; fi

  # Only one instance at a time
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/steamdeck-setup.lock"
  flock -n 9 || { echo "Another instance of this script is already running."; exit 1; }

  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"; [ -n "${SUDO_KEEPALIVE:-}" ] && kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

  for c in curl jq unzip python3; do need "$c"; done

  # --- sudo password (not set after a SteamOS factory reset) ----------
  if ! passwd -S "$USER" 2>/dev/null | grep -q ' P '; then
    warn "No sudo password set yet. Set one now:"
    until passwd; do warn "That didn't work, try again:"; done
  fi
  sudo -v
  # Keep the sudo ticket alive: the Battle.net step can take long enough for it to
  # expire, which would prompt for the password again at the end.
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
  SUDO_KEEPALIVE=$!

  # CurseForge is a big download (~160 MB + the freedesktop runtime, since SteamOS
  # doesn't ship it), so start it in the background and let the other steps run meanwhile.
  CF_PID=""; CF_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/steamdeck-setup-curseforge.log"; mkdir -p "$(dirname "$CF_LOG")"
  if [ "$INSTALL_CURSEFORGE" = 1 ]; then
    if flatpak info com.overwolf.curseforge >/dev/null 2>&1; then
      log "CurseForge already installed, skipping"
    else
      log "Starting CurseForge download in the background"
      ( flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
        && flatpak install --user -y --noninteractive flathub com.overwolf.curseforge ) >"$CF_LOG" 2>&1 &
      CF_PID=$!
    fi
  fi

  # --- 1. Decky Loader -------------------------------------------------
  if [ ! -d "$HB/services" ]; then
    log "Installing Decky Loader"
    curl -fsSL https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh
  else
    log "Decky Loader already installed, skipping"
  fi

  # --- 2. Decky plugins ------------------------------------------------
  log "Installing Decky plugins"
  curl -fsSL "$STORE_API" -o "$TMP/plugins.json"
  sudo mkdir -p "$HB/plugins"
  for name in "${DECKY_PLUGINS[@]}"; do
    # never touch an installed plugin (FORCE=1 updates it)
    if [ "$FORCE" != 1 ] && [ -n "$(plugin_dir_of "$name")" ]; then
      echo "  = $name (already installed, skipping)"; continue
    fi
    hash="$(jq -r --arg n "$name" '[.[]|select(.name==$n)][0].versions[0].hash // empty' "$TMP/plugins.json")"
    [ -n "$hash" ] || { warn "Plugin not found in the store: $name"; continue; }
    curl -fsSL "$STORE_CDN/$hash.zip" -o "$TMP/plugin.zip"
    echo "$hash  $TMP/plugin.zip" | sha256sum -c --quiet - || { warn "Hash mismatch: $name"; continue; }
    # unpack to a temp dir first so a failure never leaves a half-installed plugin
    stage="$(mktemp -d -p "$TMP")"
    unzip -q "$TMP/plugin.zip" -d "$stage"
    dir="$(ls "$stage" | head -1)"
    [ -n "$dir" ] || { warn "Empty zip: $name"; continue; }
    if [ -e "$HB/plugins/$dir" ]; then sudo mv "$HB/plugins/$dir" "$HB/plugins/$dir.bak.$(date +%s)"; fi
    sudo mv "$stage/$dir" "$HB/plugins/$dir"
    CHANGED=1
    echo "  + $name"
  done

  # --- 3. CSS Loader themes --------------------------------------------
  log "Installing CSS Loader themes"
  sudo mkdir -p "$HB/themes"
  for theme in "${THEME_ORDER[@]}"; do
    existing="$(sudo grep -l -s "\"name\": *\"$theme\"" "$HB"/themes/*/theme.json 2>/dev/null | head -1 || true)"
    if [ -n "$existing" ] && [ "$FORCE" != 1 ]; then
      ensure_theme_config "$(basename "$(dirname "$existing")")" "$theme"
      echo "  = $theme (already installed, existing settings untouched)"; continue
    fi
    q="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$theme")"
    blob="$(curl -fsSL "$THEME_API/themes?search=$q" | jq -r --arg n "$theme" '[.items[]|select(.name==$n)][0].download.id // empty')"
    [ -n "$blob" ] || { warn "Theme not found: $theme"; continue; }
    curl -fsSL "$THEME_API/blobs/$blob" -o "$TMP/theme.zip"
    stage="$(mktemp -d -p "$TMP")"
    unzip -q "$TMP/theme.zip" -d "$stage"
    dir="$(ls "$stage" | head -1)"
    [ -n "$dir" ] || { warn "Empty zip: $theme"; continue; }
    # on update only the theme files are replaced, the existing config stays
    sudo mkdir -p "$HB/themes/$dir"
    sudo cp -a "$stage/$dir/." "$HB/themes/$dir/"
    ensure_theme_config "$dir" "$theme"
    CHANGED=1
    echo "  + $theme"
  done

  # --- 4. CurseForge: wait for the background install started above ---
  if [ -n "${CF_PID:-}" ]; then
    log "CurseForge (Flatpak)"
    if kill -0 "$CF_PID" 2>/dev/null; then echo "  still downloading in the background, waiting..."; fi
    if wait "$CF_PID"; then echo "  + CurseForge ready"
    else warn "CurseForge install failed, see $CF_LOG (re-run the script to retry)"; fi
  fi

  # --- 5. Battle.net ---------------------------------------------------
  local compat="$HOME/.local/share/Steam/steamapps/compatdata"
  local bnet1="$compat/NonSteamLaunchers/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
  local bnet2="$compat/Battle.netLauncher/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
  if [ "$INSTALL_BATTLENET" = 1 ] && { [ -e "$bnet1" ] || [ -e "$bnet2" ]; } && [ "$FORCE" != 1 ]; then
    log "Battle.net already installed, skipping"
  elif [ "$INSTALL_BATTLENET" = 1 ]; then
    log "Installing Battle.net (NonSteamLaunchers)"
    echo "  Installing silently in the background (a few minutes, no window opens)..."
    # The NonSteamLaunchers script is very chatty; keep its output in a log file
    local bnet_log="${XDG_CACHE_HOME:-$HOME/.cache}/steamdeck-setup-battlenet.log"
    mkdir -p "$(dirname "$bnet_log")"
    if curl -fsSL https://raw.githubusercontent.com/moraroy/NonSteamLaunchers-On-Steam-Deck/main/NonSteamLaunchers.sh \
        | /bin/bash -s -- "Battle.net" >"$bnet_log" 2>&1; then
      echo "  + Battle.net installed. Restart Steam to see it in your Library, then log in on first launch."
    else
      warn "Battle.net install failed, see $bnet_log (re-run the script to retry)"
    fi
  fi

  # --- 5b. Steam library shortcuts -------------------------------------
  log "Steam library shortcuts"
  # Battle.net: NonSteamLaunchers adds its shortcut when its scanner runs. If it's
  # missing, nudge the scanner service and wait a bit.
  if [ "$INSTALL_BATTLENET" = 1 ] && ! has_shortcut "Battle.net"; then
    if systemctl --user list-unit-files 2>/dev/null | grep -q nslgamescanner.service; then
      echo "  asking NonSteamLaunchers to scan for Battle.net..."
      systemctl --user restart nslgamescanner.service 2>/dev/null || true
      for _ in $(seq 1 30); do has_shortcut "Battle.net" && break; sleep 2; done
    fi
    if has_shortcut "Battle.net"; then
      echo "  + Battle.net shortcut added"
    else
      warn "No Battle.net shortcut yet. In Steam open the NSL entry (Steam menu) and press the search/scan button."
    fi
  fi
  # CurseForge: a Flatpak has no Steam entry by itself, add one.
  if [ "$INSTALL_CURSEFORGE" = 1 ] && flatpak info com.overwolf.curseforge >/dev/null 2>&1; then
    if has_shortcut "CurseForge"; then
      echo "  = CurseForge shortcut already exists"
    else
      stop_steam
      shortcut_tool --name "CurseForge" --exe /usr/bin/flatpak --args "run com.overwolf.curseforge" \
        && echo "  + CurseForge shortcut added" || warn "Could not add the CurseForge shortcut"
      start_steam
    fi
  fi

  # --- 6. Battery charge limit -----------------------------------------
  if [ "${CHARGE_LIMIT:-0}" -gt 0 ]; then
    log "Battery charge limit: ${CHARGE_LIMIT}%"
    if command -v steamosctl >/dev/null; then
      if [ "$(steamosctl get-max-charge-level 2>/dev/null || true)" = "$CHARGE_LIMIT" ]; then
        echo "  = already set"
      elif steamosctl set-max-charge-level "$CHARGE_LIMIT"; then
        echo "  + set to ${CHARGE_LIMIT}%"
      else
        warn "Could not set it - do it manually: Settings > Power > Enable battery charge limit"
      fi
    else
      warn "steamosctl not found (old SteamOS?) - set it manually: Settings > Power > Enable battery charge limit"
    fi
  fi

  # --- Restart Decky ---------------------------------------------------
  if [ "$CHANGED" = 1 ]; then
    log "Restarting Decky"
    sudo systemctl restart plugin_loader.service || true
  else
    log "Nothing changed, no need to restart Decky"
  fi

  log "DONE! Switch back to Gaming Mode (or restart Steam) - plugins and themes will be active."
}

main "$@"
