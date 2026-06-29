<#
  ezcpyssh bootstrap (Windows) — klont (oder aktualisiert) das Repo und startet `ezcpyssh setup`.
    irm https://raw.githubusercontent.com/sxty9/ezcpyssh/main/install.ps1 | iex
  Pendant zu install.sh (macOS).
#>
$ErrorActionPreference = 'Stop'

$Repo = 'https://github.com/sxty9/ezcpyssh'
$Dir  = if ($env:EZCPYSSH_DIR) { $env:EZCPYSSH_DIR } else { Join-Path $env:LOCALAPPDATA 'ezcpyssh' }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Error 'git wird benoetigt.'; exit 1 }

if (Test-Path (Join-Path $Dir '.git')) {
  Write-Host "-> aktualisiere $Dir"
  git -C $Dir pull --ff-only
} else {
  Write-Host "-> klone nach $Dir"
  New-Item -ItemType Directory -Path (Split-Path -Parent $Dir) -Force | Out-Null
  git clone --depth 1 $Repo $Dir
}

& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $Dir 'bin\ezcpyssh.ps1') setup @args
