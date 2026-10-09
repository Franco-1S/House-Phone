@echo off
rem Doppelklick: baut Haustelefon, installiert es und legt eine Desktop-Verknuepfung an.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install_windows.ps1"
echo.
pause
