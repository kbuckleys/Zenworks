#!/usr/bin/env python3
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
#
# contacts.py — PEOPLE, for Cynosure's "contacts …" and "new contact …"
# (2026-11-03, Raycast's Search Contacts). Contacts are vCards: your own in
# ~/Documents/Contacts (one .vcf a person, written here), and any a synced
# address book keeps — vdirsyncer's and khard's directories, Evolution's.
#
#   contacts.py list                         [ { name, emails, phones, org, path } ]
#   contacts.py add <name> [email] [phone]   the new card's path
#
# Only what a card says is read: FN (or N), EMAIL, TEL, ORG. Nothing leaves
# the computer.

import glob
import json
import os
import re
import sqlite3
import sys
import uuid

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local", "share")


def documents():
    try:
        import subprocess
        d = subprocess.run(["xdg-user-dir", "DOCUMENTS"], capture_output=True, text=True, timeout=3).stdout.strip()
        if d and d != HOME:
            return d
    except OSError:
        pass
    return os.path.join(HOME, "Documents")


OWN = os.path.join(documents(), "Contacts")
SYNCED = [os.path.join(DATA, "vdirsyncer", "**", "*.vcf"), os.path.join(DATA, "khard", "**", "*.vcf"),
          os.path.join(HOME, ".contacts", "**", "*.vcf"), os.path.join(DATA, "contacts", "**", "*.vcf")]


def unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text)


def unescape(v):
    return v.replace("\\n", "\n").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")


def cards(text, path):
    out = []
    for block in re.findall(r"BEGIN:VCARD(.*?)END:VCARD", unfold(text), re.S | re.I):
        c = {"name": "", "emails": [], "phones": [], "org": "", "path": path}
        n = ""
        for line in block.splitlines():
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            prop = key.split(";")[0].split(".")[-1].upper()
            value = unescape(value.strip())
            if prop == "FN":
                c["name"] = value
            elif prop == "N":
                parts = [p for p in value.split(";")[:2] if p]
                n = " ".join(reversed(parts))
            elif prop == "EMAIL" and value:
                c["emails"].append(value)
            elif prop == "TEL" and value:
                c["phones"].append(re.sub(r"^tel:", "", value, flags=re.I))
            elif prop == "ORG":
                c["org"] = value.split(";")[0]
        c["name"] = c["name"] or n or (c["emails"][0] if c["emails"] else "")
        if c["name"]:
            out.append(c)
    return out


def evolution():
    out = []
    for db in glob.glob(os.path.join(DATA, "evolution", "addressbook", "*", "contacts.db")):
        try:
            con = sqlite3.connect("file:" + db + "?immutable=1", uri=True)
            rows = con.execute("SELECT vcard FROM folder_id").fetchall()
            con.close()
        except sqlite3.Error:
            continue
        for (v,) in rows:
            out.extend(cards(v or "", ""))
    return out


def listing():
    out = []
    seen = set()
    for pattern in [os.path.join(OWN, "*.vcf")] + SYNCED:
        for path in sorted(glob.glob(pattern, recursive=True)):
            if path in seen:
                continue
            seen.add(path)
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    out.extend(cards(f.read(), path))
            except OSError:
                continue
    out.extend(evolution())
    return sorted(out, key=lambda c: c["name"].lower())


def escape(v):
    return v.replace("\\", "\\\\").replace(",", "\\,").replace(";", "\\;").replace("\n", "\\n")


def add(name, email, phone):
    name = " ".join(name.split())
    if not name:
        print("a name, first", file=sys.stderr)
        sys.exit(2)
    os.makedirs(OWN, exist_ok=True)
    safe = re.sub(r'[/\\:*?"<>|]', "", name)[:80] or "Contact"
    path = os.path.join(OWN, safe + ".vcf")
    for i in range(2, 1000):
        if not os.path.exists(path):
            break
        path = os.path.join(OWN, "%s %d.vcf" % (safe, i))
    parts = name.rsplit(" ", 1)
    lines = ["BEGIN:VCARD", "VERSION:3.0", "UID:" + str(uuid.uuid4()), "FN:" + escape(name),
             "N:" + escape(parts[-1]) + ";" + escape(parts[0] if len(parts) > 1 else "") + ";;;"]
    if email:
        lines.append("EMAIL;TYPE=INTERNET:" + escape(email))
    if phone:
        lines.append("TEL:" + escape(phone))
    lines.append("END:VCARD")
    with open(path + ".part", "w", encoding="utf-8") as f:
        f.write("\r\n".join(lines) + "\r\n")
    os.replace(path + ".part", path)
    print(path)


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what == "list":
        print(json.dumps(listing()))
    elif what == "add":
        a = sys.argv[2:] + ["", "", ""]
        add(a[0], a[1].strip(), a[2].strip())
    else:
        print("contacts.py list | add <name> [email] [phone]", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
