@echo off
chcp 65001 >nul
cd /d "%~dp0"
title BOT BASLATICI
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0baslat.ps1"
pause
