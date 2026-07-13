@echo off
cd /d "%~dp0"
echo Starting Xiangqi Server (port 8080)...
start "" "xiangqi-server.exe"
echo Server started. Close this window to stop.
pause
