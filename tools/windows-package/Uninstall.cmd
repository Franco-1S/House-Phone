@echo off
rem Haustelefon deinstallieren / uninstall
rem Settings, contacts and call history are kept. To delete them too:
rem   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall -RemoveData
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
echo.
pause
