# steamdeck-setup

Factory reset utáni automatikus Steam Deck beállító.

## Használat
Desktop Modeban, Konsole-ban:

```bash
curl -L https://raw.githubusercontent.com/marosige/steamdeck-setup/main/setup.sh | bash
```

Mit csinál:
- Decky Loader + pluginok: CSS Loader, SteamGridDB
- CSS Loader témák a beállításaiddal: Clean Gameview, Round, Switch Like Home
- CurseForge (Flatpak)
- Battle.net (NonSteamLaunchers, Proton prefix + Steam shortcut)

A script elején lévő `BEALLITASOK` blokkban módosíthatod a plugin- és témalistát meg a témabeállításokat.
Ha nincs sudo jelszavad, elkéri, hogy állíts be egyet.
Ezután Gaming Modeban a CSS Loader témák aktívak lesznek (ha nem, indítsd újra a Steamet).
