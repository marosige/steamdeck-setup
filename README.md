# steamdeck-setup

Script that sets up a freshly reset Steam Deck in one go.

## Run

In **Desktop Mode**, open Konsole:

```bash
curl -fsSL https://raw.githubusercontent.com/marosige/steamdeck-setup/main/setup.sh | bash
```

Then switch back to Gaming Mode (restart Steam if themes don't show up).
No `sudo` password after a reset? The script asks you to set one.

## What it does

- Installs **Decky Loader** with the **CSS Loader** and **SteamGridDB** plugins
- Installs the CSS Loader themes **Clean Gameview**, **Round**, **Switch Like Home**, pre-configured
- Sets the battery charge limit to 80% (Settings → Power)
- Installs **CurseForge** (Flatpak)
- Installs **Battle.net** (via [NonSteamLaunchers](https://github.com/moraroy/NonSteamLaunchers-On-Steam-Deck); installs silently, log in on first launch)

Safe to re-run: installed items are skipped and your theme settings are never overwritten.
`FORCE=1` reinstalls. Plugins, themes and settings are editable at the top of [`setup.sh`](setup.sh).

> Downloads third-party software and runs it with `sudo`. Read the script first. Unofficial, use at your own risk.

[MIT](LICENSE)
