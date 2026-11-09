<div align="center">

# 🎮 steamdeck-setup

**One command to set up a freshly reset Steam Deck the way I like it.**

Decky Loader · CSS Loader themes · SteamGridDB · CurseForge · Battle.net

🇭🇺 [Magyar leírás](README.hu.md)

</div>

---

## Quick start

1. Switch to **Desktop Mode** (hold the power button → *Switch to Desktop*).
2. Open **Konsole** and run:

```bash
curl -fsSL https://raw.githubusercontent.com/marosige/steamdeck-setup/main/setup.sh | bash
```

Or clone it first if you want to read/edit before running:

```bash
git clone https://github.com/marosige/steamdeck-setup.git
cd steamdeck-setup
./setup.sh
```

3. Go back to **Gaming Mode** (restart Steam if the themes don't show up).

> After a factory reset there is no `sudo` password yet – the script will ask you to set one.

## What it installs

| Step | What | How |
| --- | --- | --- |
| 1 | [Decky Loader](https://decky.xyz) | Official installer |
| 2 | Decky plugins: **CSS Loader**, **SteamGridDB** | Decky store, SHA-256 verified |
| 3 | CSS Loader themes: **Clean Gameview**, **Round**, **Switch Like Home** | [deckthemes.com](https://deckthemes.com) API, pre-configured |
| 4 | [CurseForge](https://www.curseforge.com) | Flatpak (`com.overwolf.curseforge`) |
| 5 | [Battle.net](https://battle.net) | [NonSteamLaunchers](https://github.com/moraroy/NonSteamLaunchers-On-Steam-Deck) – Proton prefix + Steam shortcut |

### Theme settings applied

| Theme | Settings |
| --- | --- |
| Clean Gameview | Play bar: Transparent · Alignment: Zoom-Center · Steam Cloud: off · Ignore Footer: off · Lock Logo: on |
| Round | Intensity: 10px · Outlines: Round |
| Switch Like Home | No Friends: on · Lift Hero: 0 |

## Customize

Everything configurable lives in the block at the top of [`setup.sh`](setup.sh):

```bash
DECKY_PLUGINS=("CSS Loader" "SteamGridDB")   # any plugin name from the Decky store
THEME_ORDER=("Clean Gameview" "Round" "Switch Like Home")
THEME_CONFIG=( ... )                         # per-theme settings (JSON)
INSTALL_CURSEFORGE=1
INSTALL_BATTLENET=1
```

Fork the repo, change the lists, and point the `curl` URL to your fork.

## Safe to re-run

- Already installed things (Decky, plugins, themes, CurseForge, Battle.net) are **skipped**.
- Your theme settings are **never overwritten**, even on update.
- Only one instance can run at a time (lock file).
- Decky is only restarted if something actually changed.
- Nothing is deleted – an updated plugin's old folder is kept as `<name>.bak.<timestamp>`.

Want to reinstall/update everything? `FORCE=1 ./setup.sh`

## Notes

- Battle.net opens a graphical installer – you have to click through it, and it may ask you to restart Steam.
- The script's console messages are currently in Hungarian.
- Built for SteamOS (Steam Deck LCD/OLED). It needs network access and `curl`, `jq`, `unzip`, `python3` (all preinstalled on SteamOS).

## Disclaimer

Unofficial, not affiliated with Valve, Blizzard, Overwolf or the Decky/DeckThemes projects. It downloads and runs
third-party software with `sudo` – read [`setup.sh`](setup.sh) before running it. Use at your own risk.

## License

[MIT](LICENSE)
