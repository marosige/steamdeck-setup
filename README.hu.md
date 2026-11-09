# 🎮 steamdeck-setup

**Egy parancs, és a frissen resetelt Steam Deck úgy áll, ahogy szeretem.**

🇬🇧 [English README](README.md)

## Használat

1. Válts **Desktop Modera** (power gomb nyomva → *Switch to Desktop*).
2. Konsole-ban:

```bash
curl -fsSL https://raw.githubusercontent.com/marosige/steamdeck-setup/main/setup.sh | bash
```

3. Vissza **Gaming Modera** (ha nem látszanak a témák, indítsd újra a Steamet).

Factory reset után még nincs `sudo` jelszó – a script kérni fogja, hogy állíts be egyet.

## Mit telepít

- **Decky Loader** + pluginok: **CSS Loader**, **SteamGridDB**
- CSS Loader témák, kész beállításokkal: **Clean Gameview**, **Round**, **Switch Like Home**
- **CurseForge** (Flatpak)
- **Battle.net** (NonSteamLaunchers: Proton prefix + Steam shortcut; grafikus telepítőt nyit, végig kell kattintani)

## Testreszabás

A [`setup.sh`](setup.sh) elején lévő blokkban: plugin- és témalista, témabeállítások, CurseForge/Battle.net ki-be kapcsolása.

## Többszöri futtatás

Biztonságosan újrafuttatható: a már telepített dolgokat kihagyja, a témák beállításait soha nem írja felül,
egyszerre csak egy példány futhat, és semmit nem töröl (a régi pluginmappa `.bak.<idő>` néven megmarad).
Újratelepítés/frissítés: `FORCE=1 ./setup.sh`

## Figyelem

Nem hivatalos projekt. Harmadik féltől származó szoftvert tölt le és futtat `sudo`-val – futtatás előtt olvasd el a scriptet. Saját felelősségre.
