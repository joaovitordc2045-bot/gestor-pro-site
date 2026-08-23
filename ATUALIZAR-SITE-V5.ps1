$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = "joaovitordc2045-bot/gestor-pro-site"
$Branch = "main"

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
Write-Host "   GESTOR PRO - ATUALIZAR SITE V5" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path "$Root\index.html")) { Parar "index.html nao encontrado." }
if (!(Test-Path "$Root\assets")) { Parar "Pasta assets nao encontrada." }
if (!(Test-Path "$Root\downloads")) { Parar "Pasta downloads nao encontrada." }
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

$remote = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) {
    git remote add origin "https://github.com/$Repo.git"
} elseif ($remote.Trim() -ne "https://github.com/$Repo.git") {
    git remote set-url origin "https://github.com/$Repo.git"
}

git fetch origin $Branch
if ($LASTEXITCODE -ne 0) { Parar "Falha ao consultar GitHub." }

$current = (git branch --show-current).Trim()
if ($current -ne $Branch) {
    git checkout $Branch
    if ($LASTEXITCODE -ne 0) { Parar "Nao foi possivel acessar o branch main." }
}

Set-Content "$Root\CNAME" "gestorpro.log.br" -Encoding ascii -NoNewline
if (!(Test-Path "$Root\.nojekyll")) {
    New-Item -ItemType File "$Root\.nojekyll" | Out-Null
}

Write-Host "[3/5] Preparando index, assets e downloads..."
git add -f index.html
git add -f assets
git add -f downloads
git add -f CNAME
git add -f .nojekyll

$changes = git diff --cached --name-only
if ([string]::IsNullOrWhiteSpace(($changes -join ""))) {
    Write-Host "Nenhuma diferenca detectada. Forcando novo deploy..." -ForegroundColor Yellow
    git commit --allow-empty -m "Forcar deploy Gestor PRO"
} else {
    Write-Host ""
    Write-Host "Arquivos que serao publicados:" -ForegroundColor Green
    $changes | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "O instalador Windows tem aproximadamente 82 MB; o primeiro envio pode demorar alguns minutos." -ForegroundColor Yellow
    git commit -m "Atualizar site e downloads oficiais Gestor PRO"
}
if ($LASTEXITCODE -ne 0) { Parar "Falha ao criar commit." }

Write-Host "[4/5] Enviando atualizacao para o GitHub..."
git push origin $Branch
if ($LASTEXITCODE -ne 0) { Parar "Falha ao enviar atualizacao." }

Write-Host "[5/5] Concluido."
Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   SITE E DOWNLOADS ENVIADOS COM SUCESSO" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Downloads oficiais:" -ForegroundColor White
Write-Host "Windows: https://gestorpro.log.br/downloads/Gestor-Pro-Setup-1.0.6.exe" -ForegroundColor Cyan
Write-Host "Android: https://gestorpro.log.br/downloads/Gestor-Pro-Android-0.2.12.apk" -ForegroundColor Cyan
Write-Host ""
Write-Host "Aguarde 1 a 3 minutos e pressione CTRL + F5 no site." -ForegroundColor Yellow
Write-Host ""
Read-Host "Pressione ENTER para fechar"
