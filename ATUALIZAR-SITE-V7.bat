@echo off
cd /d "%~dp0"
title Gestor PRO - Atualizar Site V7 Automatico
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ATUALIZAR-SITE-V7.ps1"
echo.
pause
