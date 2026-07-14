@echo off
chcp 65001 >nul
echo ============================================================
echo   正在构建 Debug 版本，请稍候...
echo ============================================================
cd /d "%~dp0.."
call flutter build windows --debug
if %errorlevel% neq 0 (
    echo 构建失败，请检查代码错误
    pause
    exit /b %errorlevel%
)
echo ============================================================
echo   构建成功，正在启动...
echo   按 ENTER 关闭窗口
echo ============================================================
start "" /wait build\windows\x64\runner\Debug\xiangqi.exe
echo 程序已退出
pause
