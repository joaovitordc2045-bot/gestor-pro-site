@echo off
cd /d "%~dp0"
title Gestor PRO - Atualizar Site V4
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ATUALIZAR-SITE-V4.ps1"
echo.
pause
