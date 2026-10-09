<#
  Haustelefon fuer Windows bauen + installieren.

  1. Baut die Release-Version. Flutter will dafuer Symlinks (Entwicklermodus).
     Ohne Entwicklermodus nutzt das Skript Verzeichnis-Junctions + CMake direkt
     (keine Adminrechte noetig). Nur wenn das nicht geht (z. B. allererster
     Build in einem frischen Ordner), laeuft der Build einmal mit UAC-Abfrage.
  2. Installiert nach %LOCALAPPDATA%\Programs\Haustelefon
  3. Legt Verknuepfungen auf dem Desktop und im Startmenue an
  4. Startet die App (normal, ohne Adminrechte)
#>
param(
  [switch]$BuildOnly,
  [string]$Flutter,
  # Nur bauen + installieren, die App danach nicht starten.
  [switch]$NoLaunch,
  # Nur bauen (fuer tools/make_upload.py), nichts installieren.
  [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'build'
$log = Join-Path $logDir 'windows-build-log.txt'
$status = Join-Path $logDir 'windows-build-status.txt'
$buildDir = Join-Path $root 'build\windows\x64'

# ------------------------------------------------- Build-Stufe (ggf. als Admin)
if ($BuildOnly) {
  # Flutter schreibt Fortschritt auch auf stderr - das darf nicht abbrechen.
  $ErrorActionPreference = 'Continue'
  # MSBuild-Hilfsprozesse nach dem Build beenden statt weiterlaufen lassen.
  $env:MSBUILDDISABLENODEREUSE = '1'
  Set-Location $root
  New-Item -ItemType Directory -Force $logDir | Out-Null
  Remove-Item $status -ErrorAction SilentlyContinue
  # Pakete in DIESEM Prozess aufloesen (eigenes Benutzerprofil/Pub-Cache).
  & $Flutter pub get *>&1 | Tee-Object -FilePath $log
  if ($LASTEXITCODE -ne 0) {
    Set-Content -Path $status -Value $LASTEXITCODE -Encoding ascii
    exit $LASTEXITCODE
  }
  & $Flutter build windows --release *>&1 | Tee-Object -FilePath $log -Append
  Set-Content -Path $status -Value $LASTEXITCODE -Encoding ascii
  exit $LASTEXITCODE
}

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

function Find-CMake {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
    "$env:ProgramFiles\Microsoft Visual Studio\*\*\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
  )
  foreach ($c in $candidates) {
    $hit = Get-ChildItem $c -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }
  $cmd = Get-Command cmake -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

# Build ohne Symlinks: Plugin-Ordner als Junctions verlinken, dann CMake direkt.
function Invoke-JunctionBuild([string]$flutterPath) {
  $cmake = Find-CMake
  if (-not $cmake) { return $false }
  $generatedConfig = Join-Path $root 'windows\flutter\ephemeral\generated_config.cmake'

  $ErrorActionPreference = 'Continue'
  $env:MSBUILDDISABLENODEREUSE = '1'
  Set-Location $root
  & $flutterPath pub get *>&1 | Out-Host
  # In einem frischen Ordner scheitert der erste Lauf an den Plugin-Symlinks,
  # der zweite findet die Pakete dann vor.
  if ($LASTEXITCODE -ne 0) { & $flutterPath pub get *>&1 | Out-Host }
  if ($LASTEXITCODE -ne 0) { return $false }
  # Schreibt generated_config.cmake (Pfade, Version) und bricht danach ohne
  # Entwicklermodus mit "requires symlink support" ab - das ist hier egal.
  Remove-Item $generatedConfig -ErrorAction SilentlyContinue
  & $flutterPath build windows --release --config-only *>&1 | Out-Null
  if (-not (Test-Path $generatedConfig)) { return $false }

  # Native Plugins aus der generierten Liste lesen und als Junction verlinken.
  $generated = Get-Content (Join-Path $root 'windows\flutter\generated_plugins.cmake') -Raw
  $names = [regex]::Matches($generated, 'list\(APPEND FLUTTER_(?:FFI_)?PLUGIN_LIST\s+([^)]*)\)') |
    ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ }
  $pkgConfigPath = Join-Path $root '.dart_tool\package_config.json'
  $packages = (Get-Content $pkgConfigPath -Raw | ConvertFrom-Json).packages
  $base = [Uri]::new((Join-Path $root '.dart_tool') + '\')
  $linkDir = Join-Path $root 'windows\flutter\ephemeral\.plugin_symlinks'
  New-Item -ItemType Directory -Force $linkDir | Out-Null
  foreach ($name in $names) {
    $pkg = $packages | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $pkg) { return $false }
    $target = [Uri]::new($base, $pkg.rootUri).LocalPath.TrimEnd('\')
    $link = Join-Path $linkDir $name
    # rmdir OHNE /s entfernt nur die Verknuepfung bzw. einen leeren Ordner.
    if (Test-Path $link) { cmd /c rmdir "$link" | Out-Null }
    cmd /c mklink /J "$link" "$target" | Out-Null
    if (-not (Test-Path $link)) { return $false }
  }

  # Erster Build in diesem Ordner: CMake selbst konfigurieren (macht sonst "flutter build").
  New-Item -ItemType Directory -Force $logDir | Out-Null
  if (-not (Test-Path (Join-Path $buildDir 'CMakeCache.txt'))) {
    & $cmake -S (Join-Path $root 'windows') -B $buildDir -A x64 `
      -DFLUTTER_TARGET_PLATFORM=windows-x64 *>&1 | Tee-Object -FilePath $log | Out-Host
    if ($LASTEXITCODE -ne 0) { return $false }
  }
  & $cmake --build $buildDir --config Release --target INSTALL *>&1 | Tee-Object -FilePath $log -Append | Out-Host
  return ($LASTEXITCODE -eq 0)
}

Write-Host ''
Write-Host '  H A U S T E L E F O N' -ForegroundColor Magenta
Write-Host '  Windows-Installation' -ForegroundColor DarkGray

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) { throw 'Flutter wurde nicht gefunden (nicht im PATH).' }
$flutterPath = $flutterCmd.Source

$devMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
  -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Step 'Baue die App (das kann ein paar Minuten dauern) ...'
$built = $false
if ($devMode -or $isAdmin) {
  & $PSCommandPath -BuildOnly -Flutter $flutterPath
  $built = (Test-Path $status) -and ((Get-Content $status).Trim() -eq '0')
} else {
  $built = Invoke-JunctionBuild $flutterPath
  if (-not $built -and -not $NoInstall) {
    Write-Host '    Erster Build braucht einmalig Adminrechte (Entwicklermodus ist aus).' -ForegroundColor DarkGray
    Write-Host '    Bitte die Windows-Abfrage mit "Ja" bestaetigen.' -ForegroundColor Yellow
    $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
                  '-BuildOnly', '-Flutter', "`"$flutterPath`"")
    try {
      # Nur auf den Build-Prozess selbst warten (-Wait wuerde auch auf
      # zurueckbleibende Hilfsprozesse warten und haengen).
      $p = Start-Process powershell -Verb RunAs -PassThru -ArgumentList $elevArgs
      $p.WaitForExit()
    } catch {
      Write-Host "`nAbgebrochen: Ohne Adminrechte (oder Entwicklermodus) kann Flutter nicht bauen." -ForegroundColor Red
      exit 1
    }
    $built = (Test-Path $status) -and ((Get-Content $status).Trim() -eq '0')
  }
}
$ErrorActionPreference = 'Stop'

if (-not $built) {
  Write-Host "`nBuild fehlgeschlagen. Details: $log" -ForegroundColor Red
  exit 1
}
if ($NoInstall) {
  Write-Step "Gebaut: $(Join-Path $buildDir 'runner\Release')"
  exit 0
}

$src = Join-Path $buildDir 'runner\Release'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\Haustelefon'
$exe = Join-Path $installDir 'haustelefon.exe'

Write-Step "Installiere nach $installDir ..."
Get-Process haustelefon -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
New-Item -ItemType Directory -Force $installDir | Out-Null
robocopy $src $installDir /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Kopieren fehlgeschlagen (robocopy $LASTEXITCODE)." }

Write-Step 'Lege Verknuepfungen an ...'
$shell = New-Object -ComObject WScript.Shell
foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
  $lnk = $shell.CreateShortcut((Join-Path $dir 'Haustelefon.lnk'))
  $lnk.TargetPath = $exe
  $lnk.WorkingDirectory = $installDir
  $lnk.IconLocation = "$exe,0"
  $lnk.Description = 'Haustelefon - SIP-Softphone'
  $lnk.Save()
  Write-Host "    $dir\Haustelefon.lnk"
}

if ($NoLaunch) {
  Write-Step 'Fertig! Starte Haustelefon ueber die Desktop-Verknuepfung.'
} else {
  Write-Step 'Fertig! Haustelefon startet ...'
  Start-Process $exe
}
