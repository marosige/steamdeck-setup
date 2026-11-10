#!/usr/bin/env python3
"""Add a non-Steam game shortcut to Steam (all local Steam users).

Steam must NOT be running while this writes shortcuts.vdf, or it will overwrite it.
Usage: add_shortcut.py --name NAME --exe EXE [--args ARGS] [--startdir DIR]
       add_shortcut.py --has NAME       (exit 0 if a shortcut with that name exists)
Idempotent: an existing shortcut with the same name is left alone.
"""
import argparse, glob, os, shutil, struct, sys, time, zlib

STEAM = os.path.expanduser("~/.local/share/Steam")

# --- minimal binary VDF (shortcuts.vdf) reader/writer -------------------
def parse(data, pos=0):
    out = {}
    while pos < len(data):
        t = data[pos]; pos += 1
        if t == 0x08:
            return out, pos
        end = data.index(b"\0", pos); key = data[pos:end].decode("utf-8", "replace"); pos = end + 1
        if t == 0x00:
            out[key], pos = parse(data, pos)
        elif t == 0x01:
            end = data.index(b"\0", pos); out[key] = data[pos:end].decode("utf-8", "replace"); pos = end + 1
        elif t == 0x02:
            out[key] = struct.unpack("<I", data[pos:pos + 4])[0]; pos += 4
        else:
            raise ValueError(f"unsupported vdf type {t:#x}")
    return out, pos

def dump(d):
    b = b""
    for k, v in d.items():
        kb = k.encode() + b"\0"
        if isinstance(v, dict):
            b += b"\x00" + kb + dump(v)
        elif isinstance(v, int):
            b += b"\x02" + kb + struct.pack("<I", v & 0xFFFFFFFF)
        else:
            b += b"\x01" + kb + str(v).encode() + b"\0"
    return b + b"\x08"

def shortcut_files():
    files = []
    for d in glob.glob(os.path.join(STEAM, "userdata", "*")):
        if os.path.basename(d).isdigit() and os.path.basename(d) != "0":
            files.append(os.path.join(d, "config", "shortcuts.vdf"))
    return files

def load(path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        with open(path, "rb") as f:
            root, _ = parse(f.read())
        return root
    return {}

def names(root):
    sc = root.get("shortcuts", {})
    return [str(v.get("AppName", v.get("appname", ""))) for v in sc.values() if isinstance(v, dict)]

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--name"); p.add_argument("--exe"); p.add_argument("--args", default="")
    p.add_argument("--startdir", default=""); p.add_argument("--has")
    a = p.parse_args()
    files = shortcut_files()
    if a.has:
        sys.exit(0 if any(a.has in names(load(f)) for f in files) else 1)
    if not (a.name and a.exe):
        p.error("--name and --exe are required")
    if not files:
        print("No Steam user found (log in to Steam once first)", file=sys.stderr); sys.exit(2)
    exe = f'"{a.exe}"'
    appid = (zlib.crc32((exe + a.name).encode()) | 0x80000000)
    for f in files:
        root = load(f)
        if a.name in names(root):
            print(f"= {a.name}: shortcut already exists ({f})"); continue
        sc = root.setdefault("shortcuts", {})
        idx = str(max([int(k) for k in sc if k.isdigit()] + [-1]) + 1)
        sc[idx] = {
            "appid": appid, "AppName": a.name, "Exe": exe,
            "StartDir": f'"{a.startdir or os.path.dirname(a.exe)}"',
            "icon": "", "ShortcutPath": "", "LaunchOptions": a.args,
            "IsHidden": 0, "AllowDesktopConfig": 1, "AllowOverlay": 1, "OpenVR": 0,
            "Devkit": 0, "DevkitGameID": "", "DevkitOverrideAppID": 0,
            "LastPlayTime": 0, "FlatpakAppID": "", "tags": {},
        }
        os.makedirs(os.path.dirname(f), exist_ok=True)
        if os.path.exists(f):
            shutil.copy2(f, f + f".bak_{int(time.time())}")
        tmp = f + ".tmp"
        with open(tmp, "wb") as fh:
            fh.write(dump(root))
        os.replace(tmp, f)
        print(f"+ {a.name}: shortcut added ({f})")

if __name__ == "__main__":
    main()
