@echo off
chcp 65001 >nul
echo =============================
echo  正在构建 Release 版本...
echo =============================
cd /d "%~dp0.."
call flutter build windows --release
if %errorlevel% neq 0 (
    echo 构建失败
    pause
    exit /b %errorlevel%
)
echo 构建成功
pause
