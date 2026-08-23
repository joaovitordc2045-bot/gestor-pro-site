@echo off
cd /d "%~dp0"
title Gestor PRO - Atualizar Site V5
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ATUALIZAR-SITE-V5.ps1"
echo.
pause
