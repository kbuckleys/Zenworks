// ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
// ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
// └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
// https://github.com/kbuckleys/
//
// THE FILE GLYPHS — what a file or a directory LOOKS like, by name.
//
// In morpheus rather than in terminus, because two layers ask the same
// question. Terminus draws a listing; artemis draws search results over the
// same tree, and a .rs file that is a Rust mark in one window and a blank page
// in the other is two answers to one question. Same argument that put Strings,
// Paths and Desktop here.
//
// It used to PARSE ~/.config/yazi/flavors/ZENON.yazi/flavor.toml at startup,
// on the argument that the flavor already carried the rules and a second copy
// would drift from the first. The argument was sound and the arrangement was
// still wrong: it made a file manager's icons a property of a DIFFERENT
// program's theme. This shell could not add a rule without editing yazi, could
// not be given a glyph yazi has no opinion about, and rendered every file as a
// blank page on a machine where yazi is not installed or the flavor is named
// something else. A window should not depend on another application's
// configuration to know what a .rs file looks like.
//
// So the table lives here now, seeded from the choices that flavor had already
// made — those were right, and nothing is served by picking different ones —
// and extended with everything it was missing.
//
// ── how a glyph is chosen ───────────────────────────────────────────────
// Yazi's own precedence, kept because it is the correct one: the most specific
// rule that matches wins. An exact filename beats an extension, and an
// extension beats the catch-all condition for "is a directory" or "is not".
// Directories are matched against DIRS and never against EXTS, because
// "src.old" is a directory, not an .old file.
//
// Names are compared LOWERCASED. "Makefile", "makefile" and "MAKEFILE" are one
// rule, and a file called ".BASHRC" is not a stranger.
//
// ── how the glyphs were chosen ──────────────────────────────────────────
// Every one of them is a real nerd-fonts glyph, resolved by NAME out of
// nerd-fonts' own glyphnames.json and checked against the codepoints
// JetBrainsMono Nerd Font actually ships — not typed from memory. A glyph the
// font does not carry renders as nothing at all, which is indistinguishable
// from a rule that was never written.


// What a thing IS, when nothing more specific has an opinion.
.pragma library
// ONE COPY FOR THE WHOLE SHELL. Without the pragma every component instance
// that imports this file — every row, tile, card and sheet — evaluated all of
// it again; a profile caught terminus.js and icons.js costing hundreds of ms
// that way (qmlprofiler, 2026-10-09).
.import qs.morpheus as Morpheus
// The glyphs chosen by hand (morpheus/FileGlyphs, terminus' Change glyph…):
// the same instance the shell's `import "../morpheus"` sees. Node tests have
// no QML, and no choices.
var FileGlyphs = typeof Morpheus !== "undefined" ? Morpheus.FileGlyphs : globalThis.FileGlyphs;

const CONDS = {
  "!dir": "", "block": "", "char": "",
  "dir": "", "dummy": "", "exec": "",
  "fifo": "", "link": "", "orphan": "",
  "sock": "", "sticky": ""
};

// An exact filename. The most specific rule there is, and the only one that
// can tell a Cargo.toml from any other .toml.
const FILES = {
  ".bash_history": "󱆃", ".bashrc": "󱆃", ".dockerignore": "",
  ".editorconfig": "", ".env": "", ".env.local": "",
  ".eslintrc": "", ".eslintrc.json": "", ".gitattributes": "",
  ".gitconfig": "󰊢", ".gitignore": "", ".gitkeep": "󰊢",
  ".gitlab-ci.yml": "", ".gitmodules": "󰊢", ".inputrc": "󰑷",
  ".npmrc": "", ".nvmrc": "", ".prettierrc": "",
  ".profile": "󰑷", ".srcinfo": "󰣇", ".tmux.conf": "",
  ".travis.yml": "", ".vimrc": "", ".xinitrc": "󰑷",
  ".xprofile": "󰑷", ".zprofile": "󰑷", ".zshenv": "󰑷",
  ".zshrc": "󰑷", "authors": "", "bun.lockb": "",
  "cargo.lock": "󱘗", "cargo.toml": "󱘗", "changelog": "",
  "changelog.md": "", "cmakelists.txt": "", "code_of_conduct.md": "",
  "compose.yaml": "", "compose.yml": "", "config": "",
  "containerfile": "", "contributing.md": "", "copying": "󰿃",
  "default.nix": "󱄅", "docker-compose.yaml": "", "docker-compose.yml": "",
  "dockerfile": "", "flake.lock": "󱄅", "flake.nix": "󱄅",
  "gemfile": "", "gemfile.lock": "", "gnumakefile": "",
  "go.mod": "󰟓", "go.sum": "󰟓", "go.work": "󰟓",
  "hypr.conf": "", "hypridle.conf": "", "hyprland.conf": "",
  "hyprland.lua": "", "hyprlauncher.conf": "", "hyprlock.conf": "",
  "hyprpaper.conf": "", "hyprqt6engine.conf": "", "hyprsunset.conf": "",
  "hyprtoolkit.conf": "", "install": "", "justfile": "",
  "licence": "󰿃", "license": "󰿃", "license.md": "󰿃",
  "makefile": "", "meson.build": "", "news": "",
  "package-lock.json": "", "package.json": "", "pipfile": "󰌠",
  "pipfile.lock": "󰌠", "pkgbuild": "󰣇", "pnpm-lock.yaml": "",
  "poetry.lock": "󰌠", "procfile": "", "pyproject.toml": "󰌠",
  "rakefile": "", "readme": "", "readme.md": "",
  "requirements.txt": "󰌠", "rust-toolchain.toml": "󱘗", "setup.cfg": "󰌠",
  "setup.py": "󰌠", "shell.nix": "󱄅", "todo": "",
  "todo.md": "", "tox.ini": "󰌠", "tsconfig.json": "",
  "unlicense": "󰿃", "vagrantfile": "", "yarn.lock": "",
  // 11-05: more kinds, glyphs checked against the shipped Nerd Font
  "lock": "\uF023", "log": "\uF4ED", "qmldir": "\uE87D", "zshrc": "\u{F0477}",
  "bashrc": "\u{F0477}", "version": "\u{F04F9}", "tags": "\u{F04F9}",
  "url": "\uF0C1", "database": "\u{F01BC}", "database-wal": "\u{F01BC}",
  "database-shm": "\u{F01BC}", ".zsh_history": "\u{F02DA}",
  ".python_history": "\u{F02DA}", ".node_repl_history": "\u{F02DA}",
  ".lesshst": "\u{F02DA}", ".sqlite_history": "\u{F02DA}",
  ".psql_history": "\u{F02DA}", ".wget-hsts": "\u{F02DA}",
  ".viminfo": "\uE62B", "init.vim": "\uE62B", "init.lua": "\uE62B",
  "bookmarks": "\u{F00C0}", "bookmarks.xbel": "\u{F00C0}",
  "user-dirs.dirs": "\uE615", "user-dirs.locale": "\uE615",
  "mimeapps.list": "\uE615", ".xresources": "\uE615", ".xdefaults": "\uE615"
};

// A directory by name. Never consulted for a file, and never crossed with
// EXTS — a directory called "assets" is not a .assets.
const DIRS = {
  ".android": "󰓷", ".aws": "", ".bash": "󰑷",
  ".bun": "", ".cache": "", ".cargo": "󱣘",
  ".claude": "", ".config": "", ".deno": "",
  ".docker": "", ".emacs.d": "", ".fonts": "",
  ".git": "󰊢", ".github": "", ".gnupg": "",
  ".go": "󰟓", ".gradle": "", ".icons": "",
  ".idea": "", ".java": "", ".kube": "",
  ".local": "", ".m2": "", ".mozilla": "",
  ".npm": "", ".nvm": "", ".obsidian": "",
  ".pki": "", ".rustup": "", ".ssh": "",
  ".steam": "", ".terraform": "", ".themes": "󰏘",
  ".thunderbird": "󰇮", ".tmux": "", ".trash": "",
  ".venv": "󰌠", ".vim": "", ".vscode": "",
  ".wine": "", ".zen": "󰺕", ".zsh": "󰑷",
  "__pycache__": "󰌠", "__tests__": "󰙨", "addons": "",
  "api": "󱂛", "app": "󰅩", "arch": "󰣇", "attachments": "󰁦",
  "archive": "", "archives": "", "assets": "",
  "audio": "󰎅", "audiobooks": "", "backup": "",
  "backups": "", "bin": "", "bittorrents": "",
  "books": "", "boot": "", "build": "",
  "calendar": "\uEAB0",
  "cache": "", "captures": "󰹑", "certs": "",
  "claude": "", "clio": "", "cliphist": "", "components": "",
  "controllers": "", "courses": "", "database": "",
  "db": "", "desktop": "", "dev": "",
  "development": "", "discord": "", "dist": "",
  "django": "", "doc": "", "docs": "",
  "documents": "\uEAAC", "downloads": "󰃘", "dropbox": "",
  "electron": "󱀤", "elixir": "", "etc": "",
  "extensions": "", "fast": "", "fish": "",
  "flatpak": "", "flask": "", "fonts": "", "foot": "󰽒",
  "games": "", "gdrive": "", "git": "󰊢",
  "go": "󰟓", "gtk-3.0": "", "gtk-4.0": "",
  "gtk-5.0": "", "helpers": "", "home": "",
  "hooks": "", "hypr": "", "hyprland": "",
  "icons": "", "images": "", "img": "",
  "include": "󰅩", "internal": "󰅩", "keys": "", "journals": "󰭤",
  "laravel": "", "lib": "󰅩", "library": "",
  "log": "", "logs": "", "lost+found": "",
  "lua": "", "mail": "󰇮", "man": "",
  "memes": "", "migrations": "", "mnt": "",
  "models": "", "movies": "", "mozilla": "",
  "mpv": "", "music": "", "neovim": "",
  "nest": "", "nextcloud": "", "node_modules": "",
  "notes": "", "nvim": "", "obj": "",
  "obsidian": "", "onedrive": "", "opt": "",
  "out": "", "paru": "󰣇", "phoenix": "",
  "pictures": "", "pkg": "󰅩", "plugins": "",
  "podcasts": "󰎅", "proc": "", "projects": "󰲃",
  "public": "", "pulse": "", "repos": "󰊢",
  "root": "", "ruby": "", "run": "",
  "rust": "", "sbin": "", "schema": "",
  "screenshots": "󰹑", "scripts": "󰑷", "secrets": "",
  "services": "", "snippets": "\uEB66", "sounds": "󰎅", "spec": "󰙨",
  "spicetify": "", "spoot": "", "spotify": "",
  "spotify-player": "", "spotifyd": "", "spring boot": "",
  "sql": "", "src": "󰅩", "srv": "",
  "static": "", "sync": "", "sys": "",
  "target": "", "templates": "󰈙", "test": "󰙨",
  "tests": "󰙨", "themes": "󰏘", "third_party": "",
  "tmp": "", "tools": "", "torrents": "",
  "trash": "", "usr": "", "utils": "",
  "ubisoft": "\u{F0BDA}", "ubisoft connect": "\u{F0BDA}", "ubisoft game launcher": "\u{F0BDA}",
  // the other game stores' and engines' directories (2026-11-05), by the
  // names their launchers make; Steam's wear .steam's glyph. Epic, Riot,
  // Rockstar and Bethesda have no Nerd glyph; a bare "ea" is too common.
  "steam": "\uF1B7", "steamapps": "\uF1B7", "steamlibrary": "\uF1B7",
  ".minecraft": "\u{F0373}", "minecraft": "\u{F0373}",
  "gog": "\u{F0BA1}", "gog games": "\u{F0BA1}", "gog galaxy": "\u{F0BA1}",
  "battle.net": "\uEF94", "blizzard": "\uEF94",
  "itch": "\uEF99", "itch.io": "\uEF99",
  "origin games": "\u{F0B43}", "ea games": "\u{F0B43}",
  "ea desktop": "\u{F0B43}", "electronic arts": "\u{F0B43}",
  "humble": "\u{F0744}", "humble bundle": "\u{F0744}", "humble app": "\u{F0744}",
  "xboxgames": "\u{F05B9}", "xbox games": "\u{F05B9}",
  "unity hub": "\u{F06AF}", "godot": "\uE7EE",
  "var": "", "vendor": "", "venv": "󰌠",
  "videos": "", "views": "", "vim": "",
  "backgrounds": "", "wallpapers": "", "wine": "", "work": "",
  "workspace": "", "yay": "󰣇", "zen": "󰺕",
  // 11-05: more kinds, glyphs checked against the shipped Nerd Font
  "github": "\u{F02A4}", "glab-cli": "\u{F0BA0}",
  "gitlab": "\u{F0BA0}", ".gitlab": "\u{F0BA0}", "chromium": "\u{F02AF}",
  "google-chrome": "\u{F02AF}", "google-chrome-beta": "\u{F02AF}",
  "inkscape": "\uF33B", "vulkan": "\uE952", "xorg": "\uF369", "kde": "\uF373",
  "kdeconnect": "\uF373", "kactivitymanagerd": "\uF373", "kwalletd": "\uF373",
  "kio": "\uF373", "kservices5": "\uF373", "klipper": "\uF373",
  "gnome": "\u{F02AC}", "gnome-shell": "\u{F02AC}",
  "gnome-session": "\u{F02AC}", "gnome-control-center": "\u{F02AC}",
  "qtproject": "\uE87D", "qt5ct": "\uE87D", "qt6ct": "\uE87D",
  "fcitx": "\u{F030C}", "fcitx5": "\u{F030C}", "ibus": "\u{F030C}",
  "applications": "\u{F003B}", "qalculate": "\u{F00EC}", "khal": "\u{F00ED}",
  "vdirsyncer": "\u{F00ED}", "songrec": "\u{F075A}", "nerdfonts": "\uE659",
  "fontconfig": "\uE659", "shaders": "\uE855", "shader": "\uE855",
  "glsl": "\uE855", "bookmarks": "\u{F00C0}", "history": "\u{F02DA}",
  "databases": "\u{F01BC}", "ceres": "\u{F08C7}", "delphi": "\uF419",
  "kairos": "\u{F0996}", "picasso": "\u{F0F49}", "terminus": "\uF114",
  "alexandria": "\uF031", "plato": "\u{F06D3}", "oracle": "\uF013",
  "argus": "\u{F16FF}", "chronos": "\uEAB0", "calypso": "\uEB11",
  "cynosure": "\uF002",
  "minerva": "\u{F03D2}", "hestia": "\u{F0E2E}"
};

// By extension, which is what most files are recognized by.
const EXTS = {
  "xbm": "",
  "qml": "",
  "bz2": "",
  "1": "", "2": "", "3": "", "3ds": "",
  "3g2": "", "3gp": "󰎅", "5": "", "7": "",
  "7z": "", "8": "", "8svx": "󰎅", "a": "",
  "aa": "󰎅", "aab": "󰓷", "aac": "󰎅", "aax": "󰎅",
  "abw": "", "ac": "", "ac3": "󰎅", "ace": "",
  "act": "󰎅", "adoc": "", "ai": "", "aif": "󰎅",
  "aifc": "󰎅", "aiff": "󰎅", "alac": "󰎅", "am": "",
  "amr": "󰎅", "amv": "", "ape": "󰎅", "apk": "󰓷",
  "apkm": "󰓷", "apng": "", "appimage": "", "appx": "",
  "arc": "", "archive": "", "arj": "", "arrow": "",
  "arw": "", "asc": "", "asciidoc": "", "asf": "",
  "asm": "", "asp": "", "aspx": "", "ass": "",
  "astro": "", "au": "󰎅", "avi": "", "avif": "",
  "avro": "", "awb": "󰎅", "awk": "󰑷", "azw": "",
  "azw3": "", "bak": "", "bash": "󰑷", "bat": "",
  "bazel": "", "bdf": "", "bib": "", "bin": "",
  "blend": "", "bmp": "", "br": "", "bzip": "",
  "bzl": "", "c": "", "c++": "", "cab": "󰪶",
  "cabal": "", "caf": "󰎅", "cbr": "", "cbz": "",
  "cc": "", "cda": "󰎅", "cer": "", "cfg": "",
  "cfm": "", "cgi": "", "chm": "", "cjs": "",
  "class": "", "clj": "", "cljc": "", "cljs": "",
  "cls": "", "cmake": "", "cmd": "", "cnf": "",
  "compress": "", "conf": "", "cpio": "", "cpp": "",
  "cr": "", "cr2": "", "cr3": "", "crdownload": "",
  "crt": "", "crx": "", "cs": "", "csh": "󰑷",
  "css": "", "csv": "", "cue": "", "cur": "",
  "cxx": "", "d": "", "dae": "", "dart": "",
  "db": "", "dds": "", "deb": "", "der": "",
  "desktop": "", "dff": "󰎅", "diff": "", "divx": "",
  "djvu": "", "dll": "", "dmg": "", "dng": "",
  "doc": "", "dockerfile": "", "dockerignore": "", "docx": "",
  "download": "", "dpkg": "󱧘", "drc": "", "dsf": "󰎅",
  "dss": "󰎅", "dts": "󰎅", "dump": "", "dvf": "󰎅",
  "dwg": "", "dxf": "", "dylib": "", "ear": "",
  "editorconfig": "", "edn": "", "eex": "", "efi": "󰍛",
  "ejs": "", "el": "", "elf": "", "elm": "",
  "email": "󰇮", "eml": "󰇮", "emlx": "󰇮", "env": "",
  "eot": "", "eps": "", "epub": "", "erl": "",
  "ex": "", "exe": "", "exr": "", "exs": "",
  "f": "", "f4a": "", "f4b": "", "f4m": "",
  "f4p": "", "f4v": "", "f90": "", "f95": "",
  "fb2": "", "fbx": "", "feather": "", "fig": "",
  "fish": "", "flac": "󰎅", "flatpak": "", "flatpakref": "",
  "flv": "", "fnt": "", "fon": "", "for": "",
  "fw": "󰍛", "gd": "", "gem": "", "gif": "",
  "gifv": "", "glb": "", "gltf": "", "go": "󰟓",
  "gpg": "", "gpx": "󰗀", "gql": "", "gradle": "",
  "graphql": "", "groovy": "", "gsm": "󰎅", "gz": "",
  "gzip": "", "h": "", "h++": "", "h264": "",
  "h5": "", "hbs": "", "hcl": "", "hdf5": "",
  "hdr": "", "heex": "", "heic": "", "heif": "",
  "hh": "", "hpp": "", "hrl": "", "hs": "",
  "htm": "", "html": "", "hx": "", "hxx": "",
  "icns": "", "ico": "", "ics": "", "idx": "",
  "iklax": "󰎅", "img": "", "inf": "", "ini": "",
  "inl": "", "ipynb": "", "iso": "", "it": "󰎅",
  "ivs": "󰎅", "j2": "", "j2c": "", "j2k": "",
  "jar": "", "java": "", "jfif": "", "jinja": "",
  "jks": "", "jl": "", "jp2": "", "jpc": "",
  "jpe": "", "jpeg": "", "jpf": "", "jpg": "",
  "jpm": "", "jpq2": "", "jpx": "", "js": "",
  "json": "", "json5": "", "jsonc": "", "jsp": "",
  "jsx": "", "jxl": "", "kdbx": "", "key": "󰐩",
  "keytab": "", "kml": "󰗀", "ko": "", "kra": "",
  "ksh": "󰑷", "kt": "", "kts": "", "latex": "",
  "less": "", "lha": "", "lhs": "", "lisp": "",
  "list": "", "lnk": "", "lock": "", "log": "",
  "lrc": "", "lsp": "", "lua": "", "luac": "",
  "lz": "", "lz4": "", "lzh": "", "lzma": "",
  "lzo": "", "m": "", "m2p": "", "m2ts": "",
  "m2v": "", "m3u": "", "m3u8": "", "m4": "",
  "m4a": "󰎅", "m4b": "󰎅", "m4p": "󰎅", "m4v": "",
  "mak": "", "manifest": "", "map": "", "markdown": "",
  "md": "", "md5": "", "mdf": "", "mdx": "",
  "me": "", "mid": "󰎅", "midi": "󰎅", "mj2": "",
  "mjs": "", "mk": "", "mka": "", "mkv": "",
  "ml": "", "mli": "", "mm": "", "mmf": "󰎅",
  "mng": "", "mo": "󰗊", "mobi": "", "mod": "󰎅",
  "mogg": "󰎅", "mount": "", "mov": "", "movpkg": "󰎅",
  "mp1": "󰎅", "mp2": "󰎅", "mp3": "󰎅", "mp4": "",
  "mpc": "󰎅", "mpe": "", "mpeg": "", "mpg": "",
  "mpv": "", "msg": "󰇮", "msi": "", "msix": "",
  "msv": "󰎅", "mts": "", "mustache": "", "mxf": "",
  "mysql": "", "nasm": "", "nef": "", "nfo": "",
  "nim": "", "nims": "", "ninja": "", "nix": "󱄅",
  "njk": "", "nmf": "󰎅", "nomad": "", "npy": "",
  "npz": "", "nrg": "", "nsv": "", "numbers": "",
  "nupkg": "", "o": "", "obj": "", "odf": "",
  "odg": "", "odp": "󰐩", "ods": "", "odt": "",
  "oft": "󰇮", "oga": "󰎅", "ogg": "󰎅", "ogm": "",
  "ogv": "", "old": "", "opus": "󰎅", "orc": "",
  "orf": "", "org": "", "orig": "", "ost": "󰇮",
  "otc": "", "otf": "", "otp": "󰐩", "ots": "",
  "ott": "", "ova": "", "ovf": "", "p12": "",
  "pages": "", "parquet": "", "part": "", "partial": "",
  "patch": "", "pbm": "", "pc": "", "pcf": "",
  "pdf": "", "pef": "", "pem": "", "pfb": "",
  "pfm": "", "pfx": "", "pgm": "", "php": "",
  "pickle": "", "pict": "", "pid": "", "pjp": "",
  "pjpeg": "", "pkg": "", "pkl": "", "pl": "",
  "plist": "󰗀", "pls": "", "ply": "", "pm": "",
  "png": "", "pnm": "", "po": "󰗊", "pot": "󰗊",
  "ppm": "", "pps": "󰐩", "ppt": "󰐩", "pptx": "󰐩",
  "prefs": "", "properties": "", "proto": "", "ps": "",
  "ps1": "", "psd": "", "psd1": "", "psf": "",
  "psm1": "", "psql": "", "pst": "󰇮", "pub": "",
  "pug": "", "py": "󰌠", "pyc": "󰌠", "pyi": "󰌠",
  "pyw": "󰌠", "pyx": "󰌠", "qcow2": "", "qoi": "",
  "qt": "", "r": "", "ra": "󰎅", "raf": "",
  "rake": "", "rar": "", "rasi": "", "raw": "",
  "rb": "", "rc": "", "reg": "", "rej": "",
  "rf64": "󰎅", "rkt": "", "rlib": "󱘗", "rm": "󰎅",
  "rmd": "", "rmeta": "󱘗", "rmvb": "", "rom": "󰍛",
  "ron": "󱘗", "roq": "", "rpm": "", "rs": "󱘗",
  "rss": "", "rst": "", "rtf": "", "rules": "",
  "rw2": "", "s": "", "s3m": "󰎅", "sass": "",
  "sav": "", "sbt": "", "sbv": "", "sc": "",
  "scad": "", "scala": "", "scm": "", "scss": "",
  "sed": "󰑷", "service": "", "sfd": "", "sh": "󰑷",
  "sha1": "", "sha256": "", "shn": "󰎅", "sid": "󰎅",
  "sig": "", "sit": "", "sitx": "", "sketch": "",
  "sln": "󰎅", "smi": "", "snap": "", "so": "",
  "socket": "", "sol": "", "sql": "", "sqlite": "",
  "squashfs": "", "srt": "", "srw": "", "ssa": "",
  "step": "", "stl": "", "stp": "", "sty": "",
  "styl": "", "sub": "", "sum": "", "svelte": "",
  "svg": "", "svi": "", "swf": "", "swift": "",
  "swn": "", "swo": "", "swp": "", "sys": "",
  "tak": "󰎅", "tar": "", "tbz": "", "tbz2": "",
  "tex": "", "tf": "", "tfstate": "", "tfvars": "",
  "tga": "", "tgz": "", "theme": "󰔎", "thrift": "",
  "tif": "", "tiff": "", "timer": "", "tlz": "",
  "tml": "", "tmp": "", "toast": "", "toml": "",
  "torrent": "", "tres": "", "ts": "", "tscn": "",
  "tsv": "", "tsx": "", "tta": "󰎅", "ttc": "",
  "ttf": "", "ttml": "", "txt": "", "txz": "",
  "tzst": "", "ui": "󰗀", "url": "", "usdz": "",
  "vala": "", "vapi": "", "vb": "", "vcd": "",
  "vcf": "󰇮", "vcs": "", "vdi": "", "vhd": "",
  "vhdx": "", "vim": "", "viv": "", "vmdk": "",
  "vob": "", "voc": "󰎅", "vox": "󰎅", "vtt": "",
  "vue": "", "w64": "󰎅", "war": "", "wasm": "",
  "wat": "", "wav": "󰎅", "wbmp": "", "webloc": "",
  "webm": "", "webp": "", "whl": "󰌠", "wma": "󰎅",
  "wmv": "", "woff": "", "woff2": "", "wpd": "",
  "wv": "󰎅", "xapk": "󰓷", "xar": "", "xcf": "",
  "xhtml": "", "xls": "", "xlsm": "", "xlsx": "",
  "xm": "󰎅", "xml": "󰗀", "xpi": "", "xpm": "",
  "xsd": "󰗀", "xsl": "󰗀", "xslt": "󰗀", "xspf": "",
  "xz": "", "yaml": "", "yml": "", "yuv": "",
  "z": "", "zig": "", "zip": "", "zipx": "",
  "zon": "", "zoo": "", "zsh": "󰑷", "zst": "",
  "zstd": "",
  // 11-05: more kinds, glyphs checked against the shipped Nerd Font
  "jsonl": "\uE60B", "ndjson": "\uE60B", "geojson": "\uE60B",
  "webmanifest": "\uE60B", "sqlite3": "\uE7C4", "sqlite-shm": "\uE7C4",
  "sqlite-wal": "\uE7C4", "sqlite-journal": "\uE7C4",
  "sqlite3-journal": "\uE7C4", "db3": "\uE7C4", "ldb": "\uE64D",
  "db-journal": "\uE64D", "db-wal": "\uE64D", "db-shm": "\uE64D",
  "mdb": "\uE64D", "accdb": "\uE64D", "pak": "\uE6AA", "asar": "\uE6AA",
  "pk3": "\uE6AA", "vpk": "\uE6AA", "node": "\uEAE8", "zwc": "\u{F0477}",
  "zsh-theme": "\u{F0477}", "bash-completion": "\u{F0477}", "frag": "\uE855",
  "vert": "\uE855", "glsl": "\uE855", "hlsl": "\uE855", "comp": "\uE855",
  "geom": "\uE855", "tesc": "\uE855", "tese": "\uE855", "spv": "\uE855",
  "wgsl": "\uE855", "qsb": "\uE855", "shader": "\uE855", "fsh": "\uE855",
  "vsh": "\uE855", "onnx": "\u{F09D1}", "tflite": "\u{F09D1}",
  "gguf": "\u{F09D1}", "ggml": "\u{F09D1}", "safetensors": "\u{F09D1}",
  "pt": "\u{F09D1}", "pth": "\u{F09D1}", "ckpt": "\u{F09D1}", "vdf": "\uF1B7",
  "acf": "\uF1B7", "swm": "\uE62B", "swl": "\uE62B", "swk": "\uE62B",
  "shada": "\uE62B", "viminfo": "\uE62B", "xbel": "\u{F00C0}",
  "menu": "\u{F05C0}", "directory": "\uE615", "backup": "\uF1DA",
  "bk": "\uF1DA", "save": "\uF1DA", "history": "\u{F02DA}",
  "hist": "\u{F02DA}", "ctags": "\u{F04F9}", "tags": "\u{F04F9}",
  "bdic": "\u{F061D}", "dic": "\u{F061D}", "dict": "\u{F061D}",
  "aff": "\u{F061D}", "info": "\u{F02FC}", "cache": "\uF49B"
};

// Own properties only. An archive holding a file called "constructor" or
// "__proto__" is a file called that, not a lookup that comes back with
// something off Object's prototype and renders as "[object Object]".
function ruleFor(table, key) {
  return Object.prototype.hasOwnProperty.call(table, key) ? table[key] : undefined;
}

function extensionOf(name) {
  const n = String(name);
  const cut = n.lastIndexOf(".");
  // a leading dot is a hidden file, not an extension: ".bashrc" has none
  if (cut <= 0 || cut === n.length - 1) return "";
  return n.slice(cut + 1).toLowerCase();
}

// ── PROGRAMS ────────────────────────────────────────────────────────────
// A program by name — for cynosure's launcher rows, where there is no file
// to judge, only a desktop entry or a command. Every program here has a mark
// of its own in the font; one that does not is simply absent, and its row
// draws no glyph at all rather than a generic one standing in for it.
//
// Keys are the names a program actually goes by: its package, its command,
// its desktop id. Several names, one glyph — "nvim", "neovim" and "neovide"
// are one program.
//
// Resolved the same way as the tables above: by NAME out of nerd-fonts'
// glyphnames.json (3.5.1, the installed font's version), each codepoint
// checked against the charset JetBrainsMono Nerd Font actually ships.
// Written as escapes, because four hundred pasted private-use characters is
// the input every tool here has at some point mangled.
//
// Where a program is also a directory rule above — ~/.config/nvim, .steam —
// it wears the directory's glyph, so the same program is not two pictures in
// two windows. Only where the directory's rule is a generic picture (bash as a
// script, .ssh as a key) does the program keep its own logo.
// U+F059F md-web, for a browser the font has no logo for
const WEB = "\uDB81\uDD9F";
// ── BY CATEGORY ─────────────────────────────────────────────────────────
// An app no name claims, by its desktop file's Categories= (user,
// 2026-11-04): a generic glyph for what it is. First listed wins, so the
// more particular kind goes first.
const CATS = {
  "WebBrowser":   WEB,             // U+F059F md-web
  "FileTransfer": "\uDB84\uDC65"   // U+F1065, torrent clients and the like
};
const CAT_ORDER = ["WebBrowser", "FileTransfer"];

const APPS = {
  // ── browsers ──
  "firefox": "\uF269", "firefox-developer-edition": "\uF269", "firefox-nightly": "\uF269",
  "google-chrome": "\uDB80\uDEAF", "google-chrome-stable": "\uDB80\uDEAF", "chrome": "\uDB80\uDEAF",
  "microsoft-edge": "\uDB80\uDDE9", "microsoft-edge-stable": "\uDB80\uDDE9", "msedge": "\uDB80\uDDE9",
  "opera": "\uE746",
  "safari": "\uE748",
  "tor-browser": "\uF371", "torbrowser-launcher": "\uF371", "tor": "\uF371",
  // A BROWSER THE FONT HAS NO LOGO FOR is known by its desktop file
  // (Categories=WebBrowser — see appGlyph's `categories`) and wears md-web
  // (user, 2026-11-04). Named here only the ones that slip past that: a
  // window whose class finds no desktop file, a browser run without one.
  "brave-origin": WEB, "brave-origin-browser": WEB, "com.brave.origin": WEB,
  "helium": WEB, "net.imput.helium": WEB,
  // ── chat and social ──
  "discord": "\uF1FF", "discord-canary": "\uF1FF", "discord-ptb": "\uF1FF",
  "vesktop": "\uF1FF", "webcord": "\uF1FF", "equibop": "\uF1FF",
  "diskord": "\uF1FF",
  "slack": "\uE8A4", "slack-desktop": "\uE8A4",
  "telegram": "\uF2C6", "telegram-desktop": "\uF2C6", "org.telegram.desktop": "\uF2C6",
  "ayugram-desktop": "\uF2C6",
  "whatsapp": "\uF232", "whatsapp-for-linux": "\uF232", "whatsie": "\uF232",
  "zapzap": "\uF232",
  "skype": "\uDB81\uDCAF", "skypeforlinux": "\uDB81\uDCAF",
  "teams": "\uDB80\uDEBB", "teams-for-linux": "\uDB80\uDEBB", "microsoft-teams": "\uDB80\uDEBB",
  "mattermost": "\uE927", "mattermost-desktop": "\uE927",
  "teamspeak": "\uEDC3", "teamspeak3": "\uEDC3", "ts3client": "\uEDC3",
  "viber": "\uED38",
  "wechat": "\uF1D7", "wechat-uos": "\uF1D7",
  "keybase": "\uEDBF", "keybase-gui": "\uEDBF",
  "mastodon": "\uDB82\uDED1",
  "reddit": "\uF1A1",
  "twitch": "\uF1E8",
  "youtube": "\uF16A", "freetube": "\uF16A",
  "thunderbird": "\uF370", "thunderbird-beta": "\uF370",
  // ── media ──
  "spotify": "\uF1BC", "spotify-launcher": "\uF1BC", "spotify-player": "\uF1BC",
  "spotifyd": "\uF1BC", "spotify-qt": "\uF1BC", "spoot": "\uF1BC",
  "ncspot": "\uF1BC",
  "mpv": "\uF36E", "celluloid": "\uF36E",
  "vlc": "\uDB81\uDD7C",
  "kodi": "\uDB80\uDF14",
  "plex": "\uDB81\uDEBA", "plex-media-player": "\uDB81\uDEBA", "plexamp": "\uDB81\uDEBA",
  "emby": "\uDB81\uDEB4", "emby-theater": "\uDB81\uDEB4",
  "soundcloud": "\uF1BE",
  "kdenlive": "\uF33C",
  "ffmpeg": "\uF384", "ffplay": "\uF384", "ffprobe": "\uF384",
  // ── graphics and making things ──
  "gimp": "\uF338",
  "inkscape": "\uF33B",
  "krita": "\uF33D",
  "blender": "\uE766",
  "freecad": "\uF336",
  "openscad": "\uF34E",
  "kicad": "\uF34C",
  "prusa-slicer": "\uF351", "prusaslicer": "\uF351",
  "figma": "\uE7DA", "figma-linux": "\uE7DA",
  "godot": "\uE7EE", "godot4": "\uE7EE",
  "unity": "\uE721", "unityhub": "\uE721",
  "unrealeditor": "\uE8CD", "unrealengine": "\uE8CD",
  "processing": "\uE86F",
  "renpy": "\uE88D",
  "arduino": "\uF34B", "arduino-ide": "\uF34B",
  "octoprint": "\uF34D",
  "typst": "\uF37F",
  "latex": "\uE81F", "pdflatex": "\uE81F", "xelatex": "\uE81F",
  "lualatex": "\uE81F", "texstudio": "\uE81F",
  // ── office and notes ──
  "libreoffice": "\uF376", "soffice": "\uF376", "libreoffice-fresh": "\uF376",
  "libreoffice-still": "\uF376",
  "libreoffice-writer": "\uF37C", "lowriter": "\uF37C",
  "libreoffice-calc": "\uF378", "localc": "\uF378",
  "libreoffice-impress": "\uF37A", "loimpress": "\uF37A",
  "libreoffice-draw": "\uF379", "lodraw": "\uF379",
  "libreoffice-math": "\uF37B", "lomath": "\uF37B",
  "libreoffice-base": "\uF377", "lobase": "\uF377",
  "obsidian": "\uE6BB",
  "notion": "\uE848", "notion-app": "\uE848", "notion-app-electron": "\uE848",
  "evernote": "\uDB80\uDE04",
  "trello": "\uE75A",
  "jira": "\uE75C",
  "confluence": "\uE799",
  // ── games ──
  "steam": "\uF1B7", "steam-native": "\uF1B7", "steam-runtime": "\uF1B7",
  "minecraft": "\uDB80\uDF73", "minecraft-launcher": "\uDB80\uDF73",
  "itch": "\uEF99", "itch-setup": "\uEF99",
  // ── files and system ──
  "dolphin": "\uDB86\uDCB4",
  "wireshark": "\uE6BA", "tshark": "\uE6BA",
  "teamviewer": "\uDB81\uDD00",
  "lastpass": "\uDB81\uDC46",
  "dropbox": "\uF16B",
  "filezilla": "\uE7DB",
  "putty": "\uE876",
  "ssh": "\uE8B1", "sshd": "\uE8B1",
  "monero": "\uED0A", "monero-wallet-gui": "\uED0A", "monerod": "\uED0A",
  "home-assistant": "\uDB81\uDFD0", "hass": "\uDB81\uDFD0",
  "wireguard": "\uF383", "wg": "\uF383", "wg-quick": "\uF383",
  "docker": "\uF308", "docker-compose": "\uF308", "dockerd": "\uF308",
  "lazydocker": "\uF308",
  "podman": "\uE866", "podman-compose": "\uE866",
  "portainer": "\uE869",
  "kubectl": "\uE81D", "kubernetes": "\uE81D", "k9s": "\uE81D",
  "minikube": "\uE81D",
  "k3s": "\uE811",
  "helm": "\uE7FB",
  "vagrant": "\uE8D0",
  "terraform": "\uE69A", "tofu": "\uE69A",
  "packer": "\uE85C",
  "nomad": "\uE846",
  "consul": "\uE79A",
  "vault": "\uE8D2",
  "pulumi": "\uE873",
  "ansible": "\uE723", "ansible-playbook": "\uE723",
  "nginx": "\uE776",
  "apache": "\uE72B", "httpd": "\uE72B", "apachectl": "\uE72B",
  "tomcat": "\uE8C3",
  "prometheus": "\uE870",
  "grafana": "\uE7F3", "grafana-server": "\uE7F3",
  "kibana": "\uE818",
  "elasticsearch": "\uE7CA",
  "jenkins": "\uE767",
  "ngrok": "\uE92E",
  "pm2": "\uE934",
  "uwsgi": "\uE8CE",
  "proxmox": "\uE937",
  "heroku": "\uE77B",
  "nix": "\uDB84\uDD05", "nix-shell": "\uDB84\uDD05", "nix-env": "\uDB84\uDD05",
  "homebrew": "\uE7FD", "brew": "\uE7FD",
  // ── window managers and desktops ──
  "hyprland": "\uF359", "hyprctl": "\uF359",
  "sway": "\uF35D", "swaymsg": "\uF35D",
  "river": "\uF381",
  "i3": "\uF35A", "i3-msg": "\uF35A",
  "bspwm": "\uF355", "bspc": "\uF355",
  "dwm": "\uF356",
  "qtile": "\uF35C",
  "xmonad": "\uF35E",
  "awesome": "\uF354",
  "fluxbox": "\uF358",
  "jwm": "\uF35B",
  "enlightenment": "\uF357",
  "cinnamon": "\uF35F",
  // ── editors and IDEs ──
  "neovim": "\uE6AE", "nvim": "\uE6AE", "neovide": "\uE6AE",
  "vim": "\uE62B", "gvim": "\uE62B", "vi": "\uE62B",
  "emacs": "\uE7CF", "emacsclient": "\uE7CF",
  "nano": "\uE838",
  "vscode": "\uEC29", "code": "\uEC29", "visual-studio-code": "\uEC29",
  "visual-studio-code-bin": "\uEC29", "code-oss": "\uEC29",
  "vscodium": "\uF372", "codium": "\uF372",
  "sublime-text": "\uE7AA", "subl": "\uE7AA", "sublime_text": "\uE7AA",
  "atom": "\uE764",
  "intellij-idea": "\uE7B5", "idea": "\uE7B5", "intellij-idea-community-edition": "\uE7B5",
  "intellij-idea-ultimate-edition": "\uE7B5",
  "clion": "\uE78E",
  "goland": "\uE7EF",
  "pycharm": "\uE877", "pycharm-community-edition": "\uE877", "pycharm-professional": "\uE877",
  "phpstorm": "\uE862",
  "rider": "\uE88F",
  "rubymine": "\uE896",
  "webstorm": "\uE8E4",
  "datagrip": "\uE7BD",
  "dataspell": "\uE7BE",
  "jetbrains-toolbox": "\uE808",
  "android-studio": "\uE71A",
  "eclipse": "\uE79E",
  "netbeans": "\uE92B",
  "rstudio": "\uE895", "rstudio-desktop": "\uE895",
  "spyder": "\uE8AE",
  "jupyter": "\uE80F", "jupyter-lab": "\uE80F", "jupyter-notebook": "\uE80F",
  "jupyterlab": "\uE80F",
  "xcode": "\uE8E8",
  "qtcreator": "\uF375",
  // ── developer tools ──
  "git": "\uDB80\uDEA2",
  "gh": "\uE709", "github-cli": "\uE709", "github-desktop": "\uE709",
  "glab": "\uE7EB", "gitlab": "\uE7EB",
  "gitea": "\uF339",
  "forgejo": "\uF335",
  "gitkraken": "\uE913",
  "sourcetree": "\uE8A9",
  "svn": "\uE8B5", "subversion": "\uE8B5",
  "hg": "\uE929", "mercurial": "\uE929",
  "postman": "\uE86B",
  "insomnia": "\uE802",
  "dbeaver": "\uE7BF",
  "sqldeveloper": "\uE8B0",
  "tmux": "\uEBC8",
  "bash": "\uE760",
  "zsh": "\uE957",
  "awk": "\uE741", "gawk": "\uE741",
  "powershell": "\uE86C", "pwsh": "\uE86C",
  "cmake": "\uE794",
  "gcc": "\uE7E5", "g++": "\uE7E5",
  "clang": "\uE823", "llvm": "\uE823", "clang++": "\uE823",
  "bazel": "\uE8F9",
  "gradle": "\uE660",
  "maven": "\uE82C", "mvn": "\uE82C",
  "npm": "\uE71E", "npx": "\uE71E",
  "pnpm": "\uE865",
  "yarn": "\uE8EC",
  "bun": "\uE76F", "bunx": "\uE76F",
  "eslint": "\uE7D2",
  "prettier": "\uE6B4",
  "vite": "\uE8D7",
  "playwright": "\uE863",
  "composer": "\uE783",
  "anaconda": "\uE715", "conda": "\uE715",
  "spack": "\uE8AA",
  "hugo": "\uE7FE",
  // ── languages ──
  "python": "\uE73C", "python3": "\uE73C", "ipython": "\uE73C",
  "node": "\uE719", "nodejs": "\uE719",
  "deno": "\uE7C0",
  "ruby": "\uE21E", "irb": "\uE21E", "gem": "\uE21E",
  "rust": "\uE7A8", "cargo": "\uE7A8", "rustc": "\uE7A8",
  "rustup": "\uE7A8",
  "go": "\uDB81\uDFD3",
  "java": "\uE66D", "javac": "\uE66D",
  "kotlin": "\uE81B", "kotlinc": "\uE81B",
  "scala": "\uE737",
  "lua": "\uE826", "luajit": "\uE826",
  "perl": "\uE769",
  "php": "\uE73D",
  "julia": "\uE80D",
  "r": "\uE881", "rscript": "\uE881",
  "dart": "\uE798",
  "flutter": "\uE7DD",
  "zig": "\uE8EF",
  "nim": "\uE841",
  "crystal": "\uE7AC",
  "elixir": "\uE62D", "iex": "\uE62D", "mix": "\uE62D",
  "erlang": "\uE7B1", "erl": "\uE7B1",
  "ocaml": "\uE84E",
  "haskell": "\uE777", "ghc": "\uE777", "ghci": "\uE777",
  "cabal": "\uE777", "stack": "\uE777",
  "racket": "\uE93A",
  "gleam": "\uE914",
  "swift": "\uE755",
  "dotnet": "\uE77F",
  "matlab": "\uE82A",
  "stata": "\uE8B2",
  // ── databases ──
  "mysql": "\uE704",
  "mariadb": "\uE828",
  "postgresql": "\uE76E", "psql": "\uE76E", "postgres": "\uE76E",
  "sqlite": "\uE7C4", "sqlite3": "\uE7C4",
  "redis": "\uE76D", "redis-server": "\uE76D", "redis-cli": "\uE76D",
  "valkey": "\uE76D",
  "mongodb": "\uE7A4", "mongo": "\uE7A4", "mongod": "\uE7A4",
  "mongosh": "\uE7A4",
  "couchdb": "\uE7A2",
  "cassandra": "\uE789",
  "clickhouse": "\uE8FE",
  "duckdb": "\uE908",
  "surrealdb": "\uE946", "surreal": "\uE946",
  "influxdb": "\uE800", "influx": "\uE800",
  "memcached": "\uE928",
  "rabbitmq": "\uE882", "rabbitmq-server": "\uE882",
  "neo4j": "\uE839",
  // ── the directory table's programs, in the glyph it already gives them ──
  "fish": "\uEE41",
  "foot": "\uDB83\uDF52", "footclient": "\uDB83\uDF52",
  "zen-browser": "\uDB83\uDE95", "zen": "\uDB83\uDE95",
  "wine": "\uEF17", "winecfg": "\uEF17", "wine64": "\uEF17",
  "spicetify": "\uF1BC",
  "cliphist": "\uED7B",
  // desktop id com.anthropic.Claude, command claude-desktop; `claude` is
  // also the CLI, which is the same logo
  "claude": "\uEC82", "claude-desktop": "\uEC82", "claude-code": "\uEC82",
  "nextcloud": "\uF0C2", "nextcloud-client": "\uF0C2",
  "electron": "\uDB84\uDC24",
  // ── this shell's own ──
  "ceres": "\uDB82\uDCC7", "paru": "\uDB82\uDCC7", "yay": "\uDB82\uDCC7",
  "pacman": "\uDB82\uDCC7", "makepkg": "\uDB82\uDCC7",
  // U+F0F49; its desktop id and command are picasso-view
  "picasso": "\uDB83\uDF49", "picasso-view": "\uDB83\uDF49",
  // U+F06D3
  "plato": "\uDB81\uDED3",
  // U+F031, the font book
  "alexandria": "\uF031",
  // U+F419, the git client
  "delphi": "\uF419",
  // U+EB11, the password manager
  "calypso": "\uEB11",
  // U+E678, the notebook (its desktop id is clio)
  "clio": "\uE678",
  // U+F114, the file manager \u2014 the glyph icarus' Files entry wears
  "terminus": "\uF114",
  // U+F1542, network and display (its desktop id is hermes; the user's pick)
  "hermes": "\uDB85\uDD42",
  // U+F16FF, the recording editor (its desktop id is argus)
  "argus": "\uDB85\uDEFF",
  // U+F03D2, the owl: the reader (its desktop id is minerva)
  "minerva": "\uDB80\uDFD2",
  // U+F0E2E, the hearth: services and logs (its desktop id is hestia)
  "hestia": "\uDB83\uDE2E",
  // U+F0996, md-progress_clock: screen time (its desktop id is kairos)
  "kairos": "\uDB82\uDD96",
  // U+F00E2, md-broom: Tidy, giving room back (its desktop id is hygieia)
  "hygieia": "\uDB80\uDCE2",
  // U+F0D13, md-fountain_pen_tip: the image writer (its desktop id is stylus)
  "stylus": "\uDB83\uDD13",
  // U+EAB0, the calendar window (its desktop id is chronos; the user's pick)
  "chronos": "\uEAB0",
  // U+F013, the gear Cynosure's Settings row wears: the settings window
  "oracle": "\uF013",
  // U+F002, the magnifier: the launcher (hot corners' own glyph for it too)
  "cynosure": "\uF002"
};

// The glyph for a launcher entry, or "" when nothing claims it. `names` is
// every name the entry goes by, most specific first: a desktop id like
// "org.telegram.desktop", a command, a display name like "Visual Studio Code".
// Each is tried whole, then as its last reverse-DNS part, then hyphenated,
// then by its first word — so "Neovim", "nvim.desktop" and "nvim ~/notes"
// all land on the same line.
// `categories`, when the caller has the entry's (Categories= of its desktop
// file), answers what no name did — see CATS: a web browser is the web
// glyph. A name in the table still wins, so a browser with a logo keeps it.
function appGlyph(names, categories) {
  const tries = [];
  for (const raw of names || []) {
    let n = String(raw || "").trim().toLowerCase();
    if (n === "") continue;
    n = n.replace(/\.desktop$/, "");
    const word = n.split(/\s+/)[0].replace(/.*\//, "");
    tries.push(n, n.split(".").pop(), n.replace(/\s+/g, "-"), word);
  }
  for (const k of tries) {
    const g = ruleFor(APPS, k);
    if (g !== undefined) return g;
  }
  // then what the desktop file says it is, in CATS' order
  const cats = categories ? Array.from(categories) : [];
  for (const c of CAT_ORDER) if (cats.indexOf(c) >= 0) return CATS[c];
  return "";
}

// ── WHEN THE EXTENSION IS NOT IN THE TABLE ───────────────────────────────
// A KIND is a coarser question than an extension and it has an answer for
// everything: terminus already decides that .crw is an image on its way to
// deciding whether to thumbnail it, and once that is known the picture glyph
// is right whether or not anyone has written a line for .crw.
//
// Which matters because EXTS is a list of extensions somebody thought of, and
// the list of image formats is not. Forty-one of the ones terminus recognizes
// had no line here — the camera raws, the HEIF family, the old raster formats
// — and every one of them drew the SAME blank page as a file type nothing has
// ever heard of, sitting in a directory beside a .cr2 that drew a picture.
//
// EACH ENTRY IS READ OUT OF THE TABLE RATHER THAN WRITTEN TWICE. There is
// exactly one image glyph, one video glyph and so on — verified across the
// tables, not assumed — so the fallback for a kind can simply BE the glyph its
// commonest member already uses, and cannot drift away from it later.
//
// Archives are the one kind with two glyphs: zip and 7z carry a box of their
// own and everything else the general one, which is the one to fall back to.
// Documents and text are not uniform either, for the same sort of reason, and
// take the generic member of each.
//
// No entry for "file" or "other". A thing with no kind is exactly what the
// plain page is for, and giving it one would be inventing a claim.
const KIND = {
  image:    EXTS["png"],
  video:    EXTS["mp4"],
  audio:    EXTS["mp3"],
  archive:  EXTS["tar"],
  document: EXTS["docx"],
  text:     EXTS["txt"],
  font:     EXTS["ttf"]
};

function kindGlyph(kind) {
  const g = KIND[kind];
  return g === undefined ? "" : g;
}

// Whether glyphFor fell all the way through — i.e. whether the caller has
// anything to gain by asking kindGlyph. Asked rather than compared against a
// literal, so the plain page can be changed in one place.
function isPlain(glyph) { return glyph === CONDS["!dir"]; }

// The glyph for one entry, or "" when nothing claims it — which the caller
// draws as the plain page CONDS["!dir"] carries.
function glyphFor(entry) { return glyphSource(entry).glyph; }

// THE SAME LOOKUP, SAYING WHICH RULE ANSWERED — terminus' Info card says
// where a glyph comes from (user, 2026-11-05). glyphFor is this, so the two
// cannot disagree. `from`:
//   "own"     chosen for this path (FileGlyphs)     key: the path
//   "dirname" a directory rule (DIRS)               key: the name
//   "dir"     every directory
//   "orphan"  a broken link
//   "name"    an exact filename (FILES)             key: the name
//   "ext"     an extension (EXTS)                   key: the extension
//   "exec"    something you can run
//   "link"    a link
//   "plain"   nothing claimed it (the plain page)
function glyphSource(entry) {
  const at = (glyph, from, key) => ({ glyph: glyph || "", from: from, key: key || "" });
  if (!entry) return at("", "plain");
  // A glyph chosen for this very entry beats every rule (per path). Read
  // from FileGlyphs.map, so a binding asking here redraws on a new choice.
  if (entry.path && FileGlyphs) {
    const own = FileGlyphs.of(entry.path);
    if (own !== "") return at(own, "own", String(entry.path));
  }
  const name = String(entry.name || "").toLowerCase();

  if (entry.isDir) {
    const d = ruleFor(DIRS, name);
    if (d !== undefined) return at(d, "dirname", name);
    return at(CONDS["dir"], "dir");
  }

  if (entry.isLink && entry.broken && CONDS["orphan"] !== undefined)
    return at(CONDS["orphan"], "orphan");

  const f = ruleFor(FILES, name);
  if (f !== undefined) return at(f, "name", name);

  const ext = extensionOf(name);
  if (ext) {
    const e = ruleFor(EXTS, ext);
    if (e !== undefined) return at(e, "ext", ext);
  }

  if (entry.isExec && CONDS["exec"] !== undefined) return at(CONDS["exec"], "exec");
  if (entry.isLink && CONDS["link"] !== undefined) return at(CONDS["link"], "link");
  return at(CONDS["!dir"], "plain");
}

// How many rules there are, which is the one thing about this table worth
// asserting from outside it: a parse that silently produced nothing is exactly
// what the old arrangement failed at, and a count that can be checked is how
// that failure stops being silent.
function ruleCount() {
  return Object.keys(CONDS).length + Object.keys(FILES).length
       + Object.keys(DIRS).length + Object.keys(EXTS).length
       + Object.keys(APPS).length;
}
