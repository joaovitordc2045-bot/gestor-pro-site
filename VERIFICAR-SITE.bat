@echo off
setlocal
title Gestor PRO - Verificar Site
echo.
echo Verificando gestorpro.log.br...
echo.
powershell.exe -NoProfile -Command "$e=@('185.199.108.153','185.199.109.153','185.199.110.153','185.199.111.153'); try {$r=Resolve-DnsName gestorpro.log.br -Type A -ErrorAction Stop ^| ? IPAddress ^| %% IPAddress; 'DNS encontrado:'; $r; if(@($r ^| ? {$e -contains $_}).Count -gt 0){Write-Host 'OK - dominio apontando para GitHub Pages.' -ForegroundColor Green; Start-Process 'https://gestorpro.log.br'} else {Write-Host 'DNS ainda nao aponta para GitHub Pages.' -ForegroundColor Yellow}} catch {Write-Host 'DNS ainda nao propagou.' -ForegroundColor Yellow}"
echo.
pause
