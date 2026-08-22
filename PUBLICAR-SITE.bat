@echo off
setlocal
cd /d "%~dp0"
title Gestor PRO - Publicar Site
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PUBLICAR-SITE.ps1"
exit /b %errorlevel%
