# ezcpyssh

**Paste a Mac‑clipboard image straight into a remote program over SSH — as if the SSH boundary weren't there.**

When you SSH into a server and run something like **Claude Code** in the terminal, you can't paste
an image: SSH terminals don't carry clipboard images, and the remote program only sees the (empty)
server clipboard. `ezcpyssh` fixes that with a single hotkey.

Press your hotkey (default **⌘⇧V**) in the terminal and ezcpyssh:

1. grabs the image from your Mac clipboard,
2. uploads it over your existing SSH connection,
3. pastes the **remote file path** — which the remote program reads as a local image.

Copy → ⌘⇧V → image attached. That's it.

---

## Install

**One‑liner (recommended):**

```sh
curl -fsSL https://raw.githubusercontent.com/sxty9/ezcpyssh/main/install.sh | bash
```

**Or clone:**

```sh
git clone https://github.com/sxty9/ezcpyssh ~/code/ezcpyssh
~/code/ezcpyssh/bin/ezcpyssh setup
```

Both run the same setup. The only manual step is flipping **one** macOS Accessibility switch for
Hammerspoon (macOS doesn't allow that from the CLI) — setup opens the right pane for you.

```
$ ezcpyssh setup
ezcpyssh – Setup
✓ macOS / Homebrew gefunden
SSH-Ziel (user@host): you@your-server        ← the only thing you type
  → teste Verbindung … ✓ erreichbar
✓ Config gespeichert · ✓ ezcpyssh nach ~/.local/bin verlinkt
✓ Hammerspoon installiert · ✓ Hotkey-Konfig geschrieben · ✓ Hammerspoon gestartet
▶ Einmalige Freigabe: Schalter „Hammerspoon" in den Einstellungen aktivieren, dann [Enter].
✓ doctor: alle Checks bestanden
```

Fully non‑interactive: `ezcpyssh setup --target you@your-server --yes`

## Usage

1. Copy any image (`⌘C`, or screenshot to clipboard with `⌃⌘⇧4`).
2. Switch to your terminal where the remote program runs.
3. Press **⌘⇧V**.

---

## Windows

The same idea works on Windows using native tooling — **PowerShell** for the clipboard +
upload, and **AutoHotkey v2** for the global hotkey (the Hammerspoon equivalent).

**Install (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/sxty9/ezcpyssh/main/install.ps1 | iex
```

**Or clone:**

```powershell
git clone https://github.com/sxty9/ezcpyssh "$env:USERPROFILE\ezcpyssh"
powershell -STA -ExecutionPolicy Bypass -File "$env:USERPROFILE\ezcpyssh\bin\ezcpyssh.ps1" setup
```

Setup asks for your SSH target, installs AutoHotkey v2 (via `winget` if missing), writes the
hotkey script, and registers it for autostart. Non‑interactive:
`ezcpyssh.ps1 setup --target you@your-server --yes`.

**Usage:** copy an image (`Ctrl+C`, or the Snipping Tool) → in your terminal press the hotkey
(default **Ctrl+Alt+V**) → the image uploads and the remote path is pasted with `Ctrl+V`.

**Commands** mirror the macOS CLI: `setup`, `send`, `doctor`, `config get|set|edit|path`,
`uninstall`, `help`, `version` — run via `powershell -File bin\ezcpyssh.ps1 <command>`.

**Windows requirements:**

- Windows 10/11 with the built‑in **OpenSSH client** (`ssh`, on `PATH` by default).
- **AutoHotkey v2** (auto‑installed via `winget`, or from <https://www.autohotkey.com/>).
- **Windows Terminal** (recommended) — its default paste binding is `Ctrl+V`, which is what the
  hotkey sends. If your terminal pastes with a different key, set it as your terminal's paste
  binding or change which window class is treated as a terminal.
- An **SSH server reachable with key auth** (uses your `~/.ssh/config`). Keep `REMOTE_DIR`
  free of spaces (default `$HOME/.cache/ezcpyssh`, expanded server‑side).

Config lives at `%APPDATA%\ezcpyssh\config`; the generated hotkey script and debug log are in
the same folder.

## Requirements

- **macOS** (uses native clipboard + Hammerspoon for the hotkey).
- **Homebrew** (used to install Hammerspoon automatically).
- An **SSH server you reach with key auth** (password‑only logins aren't automated). ezcpyssh uses
  your existing `~/.ssh/config`, so jump hosts / `ProxyCommand` (e.g. cloudflared) just work.

No credentials are stored. The only file written with your settings is `~/.config/ezcpyssh/config`.

## How it works

```
⌘⇧V ──(Hammerspoon)──> ezcpyssh send
        1. clipboard image  -> temp PNG   (native osascript «class PNGf» / «class TIFF»→sips)
        2. ssh <target>     -> $HOME/.cache/ezcpyssh/clip_<ts>.png   (one connection)
        3. remote path      -> Mac clipboard
   ──(Hammerspoon)──> ⌘V    -> path pasted; remote program reads the local image
```

Image extraction is done natively via `osascript` (no `pngpaste` — it's broken on recent macOS:
`CGImageDestinationFinalize failed for output type 'public.png'`).

## Commands

| Command | What it does |
|---|---|
| `ezcpyssh setup` | Install + configure everything (idempotent). |
| `ezcpyssh send` | Upload current clipboard image and paste the remote path (what the hotkey calls). |
| `ezcpyssh doctor` | Check config, SSH, Hammerspoon, Accessibility, hotkey. |
| `ezcpyssh config get \| set KEY VALUE \| edit \| path` | View/change settings, then reloads Hammerspoon. |
| `ezcpyssh uninstall` | Remove hotkey + config (keeps the Hammerspoon app). |
| `ezcpyssh help` / `version` | — |

### Configuration (`~/.config/ezcpyssh/config`)

```sh
SSH_TARGET="you@your-server"
REMOTE_DIR='$HOME/.cache/ezcpyssh'   # $HOME expands on the server; keep the single quotes
AUTOPASTE=1                          # standalone `send` auto-pastes; Hammerspoon forces this off
HOTKEY="cmd,shift,v"
TERMINAL_APPS="Terminal,iTerm2,Ghostty,kitty,WezTerm,Alacritty"
```

Change the hotkey, e.g.: `ezcpyssh config set HOTKEY "cmd,alt,v"`

## Troubleshooting

- **"Kein Bild im Clipboard"** — you copied text, not an image.
- **Hotkey does nothing** — run `ezcpyssh doctor`; usually the Accessibility switch for Hammerspoon
  is off. Enable it in *System Settings → Privacy & Security → Accessibility*.
- **Upload failed** — test `ssh you@your-server` manually; key auth must work non‑interactively.
- **Debug log** — every hotkey press is logged to `/tmp/ezcpyssh_hs.log`.

## License

MIT
