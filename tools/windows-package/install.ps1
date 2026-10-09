<#
  Haustelefon - Windows install / uninstall (no admin rights needed).

  Install.cmd   -> copies .\app to %LOCALAPPDATA%\Programs\Haustelefon,
                   creates Desktop + Start menu shortcuts and starts the app.
  Uninstall.cmd -> removes the program, shortcuts and the autostart entry.
                   Settings, contacts and call history are kept unless
                   -RemoveData is given.

  Packaged by tools/make_upload.py.
#>
param(
  [switch]$Uninstall,
  [switch]$RemoveData,
  [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$de = (Get-UICulture).TwoLetterISOLanguageName -eq 'de'
function T($en, $deText) { if ($de) { $deText } else { $en } }
function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

$installDir = Join-Path $env:LOCALAPPDATA 'Programs\Haustelefon'
$exe = Join-Path $installDir 'haustelefon.exe'
$shortcuts = @(
  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Haustelefon.lnk'),
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'Haustelefon.lnk')
)
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

Write-Host ''
Write-Host '  H A U S T E L E F O N' -ForegroundColor Magenta

function Stop-App {
  $running = Get-Process haustelefon -ErrorAction SilentlyContinue
  if ($running) {
    Write-Host (T '    Closing the running Haustelefon ...' '    Beende das laufende Haustelefon ...') -ForegroundColor DarkGray
    $running | Stop-Process -Force
    Start-Sleep -Milliseconds 700
  }
}

if ($Uninstall) {
  Step (T 'Uninstalling ...' 'Deinstalliere ...')
  Stop-App
  foreach ($lnk in $shortcuts) { Remove-Item $lnk -ErrorAction SilentlyContinue }
  Remove-ItemProperty -Path $runKey -Name 'Haustelefon' -ErrorAction SilentlyContinue
  if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
  if ($RemoveData) {
    # Settings (shared_preferences), contacts, call history and saved password.
    $data = Join-Path $env:APPDATA 'Haustelefon'
    if (Test-Path $data) { Remove-Item $data -Recurse -Force }
  }
  Step (T 'Done. Haustelefon has been removed.' 'Fertig. Haustelefon wurde entfernt.')
  exit 0
}

$src = Join-Path $PSScriptRoot 'app'
if (-not (Test-Path (Join-Path $src 'haustelefon.exe'))) {
  $msg = T "`nThe folder 'app' is missing. Please unzip the whole archive first." `
           "`nDer Ordner 'app' fehlt. Bitte zuerst das ganze Archiv entpacken."
  Write-Host $msg -ForegroundColor Red
  exit 1
}

Step (T "Installing to $installDir ..." "Installiere nach $installDir ...")
Stop-App
New-Item -ItemType Directory -Force $installDir | Out-Null
robocopy $src $installDir /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
# Downloaded zips mark every file as "from the internet" - not needed after install.
Get-ChildItem $installDir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

Step (T 'Creating shortcuts ...' 'Lege Verknuepfungen an ...')
$shell = New-Object -ComObject WScript.Shell
foreach ($path in $shortcuts) {
  $lnk = $shell.CreateShortcut($path)
  $lnk.TargetPath = $exe
  $lnk.WorkingDirectory = $installDir
  $lnk.IconLocation = "$exe,0"
  $lnk.Description = 'Haustelefon - SIP softphone'
  $lnk.Save()
  Write-Host "    $path"
}

# Autostart entry from an older install: keep it pointing at this exe.
if (Get-ItemProperty -Path $runKey -Name 'Haustelefon' -ErrorAction SilentlyContinue) {
  Set-ItemProperty -Path $runKey -Name 'Haustelefon' -Value "`"$exe`" --minimized"
}

if ($NoLaunch) {
  Step (T 'Done! Start Haustelefon from the desktop shortcut.' 'Fertig! Starte Haustelefon ueber die Desktop-Verknuepfung.')
} else {
  Step (T 'Done! Haustelefon is starting ...' 'Fertig! Haustelefon startet ...')
  Start-Process $exe
}
