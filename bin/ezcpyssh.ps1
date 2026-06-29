<#
  ezcpyssh.ps1 — Windows-Port von ezcpyssh.
  Fuegt ein Clipboard-Bild per Hotkey in ein SSH-Remote-Programm (z. B. Claude Code) ein:
  laedt das Bild auf den SSH-Server und fuegt den Remote-Pfad ein, den das Remote-Programm
  als lokales Bild liest. Trigger: globaler Hotkey (Default Ctrl+Alt+V) via AutoHotkey v2.
  Pendant zu bin/ezcpyssh (macOS). Siehe: https://github.com/sxty9/ezcpyssh
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Command = 'help',
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Rest = @()
)

$ErrorActionPreference = 'Stop'
$Version = '0.1.0'

# --- Pfade ----------------------------------------------------------------------------
$SelfDir   = $PSScriptRoot                          # ...\ezcpyssh\bin
$RepoRoot  = Split-Path -Parent $SelfDir            # ...\ezcpyssh
$Template  = Join-Path $RepoRoot 'share\ezcpyssh.ahk.tmpl'

$ConfigDir = Join-Path $env:APPDATA 'ezcpyssh'
$Config    = Join-Path $ConfigDir 'config'
$AhkScript = Join-Path $ConfigDir 'ezcpyssh.ahk'
$LogFile   = Join-Path $ConfigDir 'ezcpyssh.log'
$StartupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'ezcpyssh.lnk'

# --- Defaults -------------------------------------------------------------------------
$DefRemoteDir = '$HOME/.cache/ezcpyssh'   # $HOME bleibt literal -> remote-seitig expandiert
$DefHotkey    = 'ctrl,alt,v'
$DefAutopaste = '1'
$DefTerminals = 'WindowsTerminal.exe,alacritty.exe,wezterm-gui.exe,mintty.exe,Hyper.exe,powershell.exe,pwsh.exe,cmd.exe,conhost.exe'

# --- Ausgabe-Helfer -------------------------------------------------------------------
function Ok   ([string]$m) { Write-Host '[ok] ' -ForegroundColor Green  -NoNewline; Write-Host $m }
function Warn ([string]$m) { Write-Host '[!]  ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Err  ([string]$m) { Write-Host '[x]  ' -ForegroundColor Red    -NoNewline; Write-Host $m }
function Note ([string]$m) { Write-Host $m -ForegroundColor DarkGray }

function Have([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# --- Config laden / schreiben ---------------------------------------------------------
function Load-Config {
  $cfg = [ordered]@{
    SSH_TARGET    = ''
    REMOTE_DIR    = $DefRemoteDir
    HOTKEY        = $DefHotkey
    AUTOPASTE     = $DefAutopaste
    TERMINAL_APPS = $DefTerminals
  }
  if (Test-Path $Config) {
    foreach ($line in Get-Content -LiteralPath $Config) {
      if ($line -match '^\s*#') { continue }
      if ($line -match '^\s*([A-Z_]+)\s*=\s*(.*)$') {
        $cfg[$matches[1]] = $matches[2].Trim().Trim('"')
      }
    }
  }
  return $cfg
}

function Write-ConfigFile($cfg) {
  if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
  $lines = @(
    '# ezcpyssh config (Windows) — von `ezcpyssh setup/config` verwaltet'
    "SSH_TARGET=$($cfg.SSH_TARGET)"
    "REMOTE_DIR=$($cfg.REMOTE_DIR)"
    "HOTKEY=$($cfg.HOTKEY)"
    "AUTOPASTE=$($cfg.AUTOPASTE)"
    "TERMINAL_APPS=$($cfg.TERMINAL_APPS)"
  )
  Set-Content -LiteralPath $Config -Value $lines -Encoding UTF8
}

# --- Hotkey-Umwandlung: "ctrl,alt,v" -> AHK "^!v" -------------------------------------
function ConvertTo-AhkHotkey([string]$hotkey) {
  $map = @{ ctrl = '^'; control = '^'; alt = '!'; shift = '+'; win = '#'; cmd = '#'; super = '#' }
  $parts = $hotkey.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
  if ($parts.Count -lt 1) { return '^!v' }
  $key = $parts[-1]
  $mods = ''
  for ($i = 0; $i -lt $parts.Count - 1; $i++) {
    $m = $map[$parts[$i].ToLower()]
    if ($m) { $mods += $m }
  }
  return "$mods$key"
}

# --- AHK-Skript rendern ---------------------------------------------------------------
function Render-Ahk($cfg) {
  if (-not (Test-Path $Template)) { Err "Template fehlt: $Template"; return $false }
  $ahkKey = ConvertTo-AhkHotkey $cfg.HOTKEY
  $tmpl = Get-Content -LiteralPath $Template -Raw
  $tmpl = $tmpl.Replace('@@PSSCRIPT@@', (Join-Path $SelfDir 'ezcpyssh.ps1'))
  $tmpl = $tmpl.Replace('@@LOG@@',      $LogFile)
  $tmpl = $tmpl.Replace('@@TERMINALS@@', $cfg.TERMINAL_APPS)
  $tmpl = $tmpl.Replace('@@HOTKEY@@',   $ahkKey)
  $tmpl = $tmpl.Replace('@@SENDKEY@@',  $ahkKey)
  if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
  Set-Content -LiteralPath $AhkScript -Value $tmpl -Encoding UTF8
  return $true
}

# --- AutoHotkey finden / installieren / starten ---------------------------------------
function Find-AhkExe {
  $cands = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe'),  # winget per-user (Default)
    (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey32.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\AutoHotkey64.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\AutoHotkey.exe'),
    (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
    (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey32.exe'),
    (Join-Path $env:ProgramFiles 'AutoHotkey\AutoHotkey64.exe'),
    (Join-Path $env:ProgramFiles 'AutoHotkey\AutoHotkey.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\AutoHotkey.exe')
  )
  foreach ($c in $cands) { if ($c -and (Test-Path $c)) { return $c } }
  $cmd = Get-Command 'AutoHotkey64.exe','AutoHotkey.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { return $cmd.Source }
  return $null
}

function Restart-Ahk($ahkExe) {
  Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe' OR Name='AutoHotkey.exe' OR Name='AutoHotkey32.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -match 'ezcpyssh\.ahk' } |
    ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
  Start-Sleep -Milliseconds 300
  Start-Process -FilePath $ahkExe -ArgumentList "`"$AhkScript`""
}

function Set-StartupShortcut($ahkExe) {
  $ws = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut($StartupLnk)
  $lnk.TargetPath = $ahkExe
  $lnk.Arguments  = "`"$AhkScript`""
  $lnk.WorkingDirectory = $ConfigDir
  $lnk.Description = 'ezcpyssh hotkey'
  $lnk.Save()
}

# =====================================================================================
# send — Clipboard-Bild hochladen, Remote-Pfad ins Clipboard, optional einfuegen
# =====================================================================================
function Invoke-Send {
  # Clipboard-Bild braucht STA. Bei MTA mit -STA neu starten.
  if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $p = Start-Process -FilePath 'powershell.exe' -Wait -PassThru -NoNewWindow `
      -ArgumentList "-NoProfile -STA -ExecutionPolicy Bypass -File `"$PSCommandPath`" send"
    exit $p.ExitCode
  }

  $cfg = Load-Config
  if (-not $cfg.SSH_TARGET) { Err 'Kein SSH-Ziel. Erst: ezcpyssh setup'; exit 1 }

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $img = [System.Windows.Forms.Clipboard]::GetImage()
  if (-not $img) { exit 2 }   # kein Bild im Clipboard

  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ezcpyssh_" + [System.IO.Path]::GetRandomFileName() + '.png')
  try {
    $img.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)

    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $remoteDir  = $cfg.REMOTE_DIR
    $remoteFile = "$remoteDir/clip_$ts.png"
    # Remote-Befehl ohne Anfuehrungszeichen, damit das Quoting zu ssh sauber bleibt.
    # $HOME / $remoteDir expandieren remote-seitig (Pfade ohne Leerzeichen vorausgesetzt).
    $remoteCmd  = "mkdir -p $remoteDir && cat > $remoteFile && printf %s $remoteFile"

    # Upload via Start-Process mit Datei-Redirection: stdin <- PNG, stdout -> Pfad-Datei.
    # Harter Timeout + Baum-Kill, damit ein ProxyCommand (cloudflared) nichts haengen laesst.
    $outFile = "$tmp.out"; $errFile = "$tmp.err"
    $p = Start-Process ssh -PassThru -NoNewWindow `
      -RedirectStandardInput $tmp -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
      -ArgumentList @('-o','ConnectTimeout=15','-o','BatchMode=yes','-o','StrictHostKeyChecking=accept-new', $cfg.SSH_TARGET, $remoteCmd)
    if (-not $p.WaitForExit(60000)) {
      try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
      Err 'Upload-Timeout'; exit 1
    }
    # `Start-Process -PassThru` liefert keinen verlaesslichen ExitCode. Der Remote-Befehl
    # gibt den Pfad nur bei Erfolg aus (mkdir && cat && printf) -> leere Ausgabe = Fehler.
    $remotePath = (Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue)
    if (-not $remotePath) { Err 'Upload fehlgeschlagen'; exit 1 }
    $remotePath = $remotePath.Trim()

    [System.Windows.Forms.Clipboard]::SetText($remotePath)

    $autopaste = if ($env:EZCPYSSH_AUTOPASTE) { $env:EZCPYSSH_AUTOPASTE } else { $cfg.AUTOPASTE }
    if ($autopaste -eq '1') {
      Start-Sleep -Milliseconds 200
      [System.Windows.Forms.SendKeys]::SendWait('^v')
    }
    Write-Output $remotePath
    exit 0
  }
  finally {
    Remove-Item -LiteralPath $tmp, "$tmp.out", "$tmp.err" -Force -ErrorAction SilentlyContinue
  }
}

# =====================================================================================
# setup
# =====================================================================================
function Test-Ssh([string]$target) {
  # Harter Timeout via Start-Process: ein ProxyCommand (z. B. cloudflared) erbt die
  # Redirect-Handles und laesst `& ssh ... *> $null` sonst haengen; ConnectTimeout greift
  # bei ProxyCommand nicht zuverlaessig. Hier kappen wir den ganzen Prozessbaum hart.
  if (-not $target) { return $false }
  $out = Join-Path ([System.IO.Path]::GetTempPath()) ('ez_ssh_' + [System.IO.Path]::GetRandomFileName())
  try {
    $p = Start-Process ssh -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError "$out.err" `
      -ArgumentList @('-o','BatchMode=yes','-o','ConnectTimeout=10','-o','StrictHostKeyChecking=accept-new', $target, 'echo ok')
    if ($p.WaitForExit(30000)) {   # cloudflared o. ae. ProxyCommand kann beim Kaltstart traege sein
      # `Start-Process -PassThru` liefert keinen verlaesslichen ExitCode -> am Marker pruefen.
      $txt = (Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue)
      return [bool]($txt -match 'ok')
    }
    try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
    return $false
  } catch {
    return $false
  } finally {
    Remove-Item -LiteralPath $out, "$out.err" -Force -ErrorAction SilentlyContinue
  }
}

function Get-SshAliasHint {
  $cfgPath = Join-Path $env:USERPROFILE '.ssh\config'
  if (-not (Test-Path $cfgPath)) { return '' }
  $aliases = @()
  foreach ($line in Get-Content -LiteralPath $cfgPath) {
    if ($line -match '^\s*Host\s+(.+)$') {
      foreach ($h in ($matches[1].Split(' ') | Where-Object { $_ -ne '' })) {
        if ($h -notmatch '[\*\?]') { $aliases += $h }
      }
    }
  }
  return ($aliases -join ', ')
}

function Invoke-Setup($argv) {
  $target = ''; $remoteDir = ''; $hotkey = ''; $autopaste = ''; $assumeYes = $false
  for ($i = 0; $i -lt $argv.Count; $i++) {
    switch ($argv[$i]) {
      '--target'        { $target = $argv[++$i] }
      '--remote-dir'    { $remoteDir = $argv[++$i] }
      '--hotkey'        { $hotkey = $argv[++$i] }
      '--no-autopaste'  { $autopaste = '0' }
      { $_ -in '--yes','-y' } { $assumeYes = $true }
      default { Err "Unbekannte Option: $($argv[$i])"; return }
    }
  }

  Write-Host 'ezcpyssh - Setup (Windows)' -ForegroundColor Green

  $cfg = Load-Config
  if ($remoteDir) { $cfg.REMOTE_DIR = $remoteDir }
  if ($hotkey)    { $cfg.HOTKEY     = $hotkey }
  if ($autopaste) { $cfg.AUTOPASTE  = $autopaste }
  if ($target)    { $cfg.SSH_TARGET = $target }

  if (-not $cfg.SSH_TARGET -and -not $assumeYes) {
    $hint = Get-SshAliasHint
    if ($hint) { Note "  bekannte SSH-Aliase: $hint" }
    $cfg.SSH_TARGET = (Read-Host 'SSH-Ziel (user@host)').Trim()
  }
  if (-not $cfg.SSH_TARGET) { Err 'Kein SSH-Ziel. Nutze: ezcpyssh setup --target user@host'; return }

  Write-Host '  -> teste Verbindung ... ' -NoNewline
  if (Test-Ssh $cfg.SSH_TARGET) { Ok 'erreichbar' }
  else { Write-Host ''; Warn 'nicht non-interaktiv erreichbar - pruefe Key-Auth/~/.ssh/config. Fahre fort.' }

  Write-ConfigFile $cfg
  Ok "Config gespeichert ($Config)"

  $ahkExe = Find-AhkExe
  if ($ahkExe) {
    Ok "AutoHotkey gefunden ($ahkExe)"
  } else {
    if (Have 'winget') {
      Note '  AutoHotkey nicht gefunden - installiere via winget ...'
      & winget install --id AutoHotkey.AutoHotkey -e --source winget --accept-package-agreements --accept-source-agreements
      $ahkExe = Find-AhkExe
    }
    if (-not $ahkExe) {
      Err 'AutoHotkey v2 fehlt. Installiere es von https://www.autohotkey.com/ (oder `winget install AutoHotkey.AutoHotkey`) und fuehre `ezcpyssh setup` erneut aus.'
      return
    }
    Ok 'AutoHotkey installiert'
  }

  if (-not (Render-Ahk $cfg)) { return }
  Ok "Hotkey-Skript geschrieben ($AhkScript)"
  Set-StartupShortcut $ahkExe
  Ok 'Autostart-Verknuepfung angelegt'
  Restart-Ahk $ahkExe
  Ok 'AutoHotkey gestartet'

  Write-Host ''
  Invoke-Doctor | Out-Null
  Write-Host ''
  Ok "Fertig! Bild kopieren und $($cfg.HOTKEY.Replace(',','+')) im SSH-Terminal druecken."
}

# =====================================================================================
# doctor
# =====================================================================================
function Invoke-Doctor {
  $cfg = Load-Config
  $fails = 0
  Ok "Windows $([Environment]::OSVersion.Version)"

  if ($cfg.SSH_TARGET) { Ok "Config ($($cfg.SSH_TARGET), $($cfg.REMOTE_DIR))" }
  else { Err 'Config: kein SSH-Ziel - ezcpyssh setup'; $fails++ }

  if ($cfg.SSH_TARGET) {
    if (Test-Ssh $cfg.SSH_TARGET) { Ok 'SSH erreichbar' } else { Warn 'SSH nicht non-interaktiv erreichbar' }
  }

  if (Have 'ssh') { Ok 'ssh-Client vorhanden' } else { Err 'ssh fehlt - OpenSSH-Client aktivieren'; $fails++ }

  $ahkExe = Find-AhkExe
  if ($ahkExe) { Ok 'AutoHotkey installiert' } else { Err 'AutoHotkey fehlt'; $fails++ }
  if (Test-Path $AhkScript) { Ok 'ezcpyssh.ahk vorhanden' } else { Err 'ezcpyssh.ahk fehlt - ezcpyssh setup'; $fails++ }
  if (Test-Path $StartupLnk) { Ok 'Autostart-Verknuepfung vorhanden' } else { Warn 'Autostart-Verknuepfung fehlt - ezcpyssh setup' }

  $running = Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe' OR Name='AutoHotkey.exe' OR Name='AutoHotkey32.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -match 'ezcpyssh\.ahk' }
  if ($running) { Ok 'Hotkey laeuft' } else { Warn 'Hotkey-Prozess laeuft nicht (AutoHotkey-Skript starten)' }

  Write-Host ''
  if ($fails -eq 0) { Ok 'Alles gut.' } else { Err "$fails Problem(e) gefunden." }
  return ($fails -eq 0)
}

# =====================================================================================
# config / uninstall / help / version
# =====================================================================================
function Reapply-Config {
  $cfg = Load-Config
  $ahkExe = Find-AhkExe
  if ($ahkExe) { if (Render-Ahk $cfg) { Restart-Ahk $ahkExe; Ok 'AutoHotkey neu geladen' } }
}

function Invoke-Config($argv) {
  $sub = if ($argv.Count -ge 1) { $argv[0] } else { 'get' }
  switch ($sub) {
    'path' { Write-Output $Config }
    'get'  { if (Test-Path $Config) { Get-Content -LiteralPath $Config } else { Err 'Keine Config - ezcpyssh setup' } }
    'edit' { Start-Process notepad.exe -ArgumentList "`"$Config`"" -Wait; Reapply-Config }
    'set'  {
      if ($argv.Count -lt 3) { Err 'Nutzung: ezcpyssh config set KEY VALUE'; return }
      $key = $argv[1]; $val = $argv[2]
      $cfg = Load-Config
      if ($cfg.Contains($key)) { $cfg[$key] = $val } else { Err "Unbekannter Schluessel: $key"; return }
      Write-ConfigFile $cfg
      Reapply-Config
      Ok "$key gesetzt."
    }
    default { Err "Unbekanntes Unterkommando: $sub" }
  }
}

function Invoke-Uninstall {
  if (Test-Path $StartupLnk) { Remove-Item -LiteralPath $StartupLnk -Force; Ok 'Autostart-Verknuepfung entfernt' }
  Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe' OR Name='AutoHotkey.exe' OR Name='AutoHotkey32.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -match 'ezcpyssh\.ahk' } |
    ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
  if (Test-Path $AhkScript) { Remove-Item -LiteralPath $AhkScript -Force; Ok 'ezcpyssh.ahk entfernt' }
  if (Test-Path $Config) {
    $a = Read-Host "Config loeschen ($Config)? [y/N]"
    if ($a -match '^[yY]') { Remove-Item -LiteralPath $Config -Force; Ok 'Config entfernt' } else { Note 'Config behalten.' }
  }
  Note 'Hinweis: die AutoHotkey-App bleibt installiert (winget uninstall AutoHotkey.AutoHotkey zum Entfernen).'
}

function Invoke-Help {
  @"
ezcpyssh $Version (Windows) — Clipboard-Bilder per Hotkey in eine SSH-Remote-Session einfuegen

NUTZUNG
  ezcpyssh setup [--target user@host] [--remote-dir DIR] [--hotkey ctrl,alt,v] [--no-autopaste] [--yes]
                 Richtet alles ein: Config, AutoHotkey (Auto-Install via winget), Hotkey, Autostart.
  ezcpyssh send  Laedt das aktuelle Clipboard-Bild hoch und fuegt den Remote-Pfad ein
                 (das, was der Hotkey aufruft). Exit 2 = kein Bild, 1 = Upload-Fehler.
  ezcpyssh doctor          Prueft Konfiguration, SSH, AutoHotkey, Hotkey.
  ezcpyssh config get|set KEY VALUE|edit|path
  ezcpyssh uninstall       Entfernt Hotkey/Autostart/Config (AutoHotkey-App bleibt).
  ezcpyssh help | version

So funktioniert's: Bild kopieren (Strg+C / Snipping-Tool) -> im Terminal Hotkey druecken ->
ezcpyssh laedt das Bild auf den SSH-Server, der Remote-Pfad wird eingefuegt; das Remote-Programm
(z. B. Claude Code) haengt das Bild daraus an. Mehr: https://github.com/sxty9/ezcpyssh
"@ | Write-Host
}

# =====================================================================================
$argv = @($Rest)
switch ($Command) {
  'setup'     { Invoke-Setup $argv }
  'send'      { Invoke-Send }
  'doctor'    { if (-not (Invoke-Doctor)) { exit 1 } }
  'config'    { Invoke-Config $argv }
  'uninstall' { Invoke-Uninstall }
  { $_ -in 'version','--version','-v' } { Write-Host "ezcpyssh $Version" }
  { $_ -in 'help','--help','-h' }       { Invoke-Help }
  default     { Err "Unbekanntes Kommando: $Command"; Write-Host ''; Invoke-Help; exit 1 }
}
