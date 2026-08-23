$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = "joaovitordc2045-bot/gestor-pro-site"
$Branch = "main"
$Remote = "https://github.com/$Repo.git"

function Parar($msg) {
    Write-Host ""
    Write-Host "ERRO: $msg" -ForegroundColor Red
    Write-Host ""
    Read-Host "Pressione ENTER para fechar"
    exit 1
}

Set-Location $Root
Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   GESTOR PRO - ATUALIZAR SITE V4" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path "$Root\index.html")) { Parar "index.html nao encontrado." }
if (!(Test-Path "$Root\assets")) { Parar "Pasta assets nao encontrada." }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { Parar "Git nao encontrado." }
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { Parar "GitHub CLI nao encontrado." }

Write-Host "[1/5] Verificando login no GitHub..."
cmd /c "gh auth status >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { Parar "Falha no login do GitHub." }
}

Write-Host "[2/5] Preparando repositorio..."
if (!(Test-Path "$Root\.git")) {
    git init
    if ($LASTEXITCODE -ne 0) { Parar "Falha ao iniciar Git." }
}

$remoteAtual = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) {
    git remote add origin $Remote
} elseif ($remoteAtual.Trim() -ne $Remote) {
    git remote set-url origin $Remote
}

git fetch origin $Branch
if ($LASTEXITCODE -ne 0) { Parar "Falha ao consultar GitHub." }

# Guarda SOMENTE o site que o usuario quer publicar antes de sincronizar.
$Temp = Join-Path $env:TEMP ("gestor-pro-site-v4-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Temp | Out-Null
Copy-Item "$Root\index.html" "$Temp\index.html" -Force
Copy-Item "$Root\assets" "$Temp\assets" -Recurse -Force

Write-Host "Sincronizando base com o GitHub sem perder index.html/assets..."
# Limpa alteracoes locais/rastreadas que impediam pull --rebase no V3.
git reset --hard "origin/$Branch"
if ($LASTEXITCODE -ne 0) {
    Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue
    Parar "Falha ao sincronizar a base com o GitHub."
}

# Restaura exatamente o index/assets locais que o usuario deseja publicar.
Copy-Item "$Temp\index.html" "$Root\index.html" -Force
if (Test-Path "$Root\assets") { Remove-Item "$Root\assets" -Recurse -Force }
Copy-Item "$Temp\assets" "$Root\assets" -Recurse -Force
Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue

Set-Content "$Root\CNAME" "gestorpro.log.br" -Encoding ascii -NoNewline
if (!(Test-Path "$Root\.nojekyll")) {
    New-Item -ItemType File "$Root\.nojekyll" | Out-Null
}

Write-Host "[3/5] Verificando index.html e assets..."
git add -f index.html assets CNAME .nojekyll
if ($LASTEXITCODE -ne 0) { Parar "Falha ao preparar arquivos do site." }

$changes = @(git diff --cached --name-only)
if ($changes.Count -eq 0) {
    Write-Host "Nenhuma diferenca detectada. Forcando novo deploy..." -ForegroundColor Yellow
    git commit --allow-empty -m "Forcar deploy Gestor PRO"
} else {
    Write-Host "Arquivos que serao publicados:" -ForegroundColor Green
    $changes | ForEach-Object { Write-Host "  $_" }
    git commit -m "Atualizar site Gestor PRO"
}
if ($LASTEXITCODE -ne 0) { Parar "Falha ao criar commit." }

Write-Host "[4/5] Enviando atualizacao..."
# Nao usa pull --rebase aqui: a sincronizacao foi feita ANTES do commit.
git push origin $Branch
if ($LASTEXITCODE -ne 0) { Parar "Falha ao enviar atualizacao. Rode o V4 novamente; ele sincronizara a base antes de publicar." }

Write-Host "[5/5] Concluido."
Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   SITE ENVIADO COM SUCESSO" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Aguarde 1 a 3 minutos e pressione CTRL + F5 no site." -ForegroundColor Yellow
Write-Host "https://gestorpro.log.br" -ForegroundColor Cyan
Write-Host ""
Read-Host "Pressione ENTER para fechar"
