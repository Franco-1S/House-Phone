@echo off
rem Haustelefon installieren / install (no admin rights needed)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
