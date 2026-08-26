$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = "joaovitordc2045-bot/gestor-pro-site"
$Branch = "main"
$Downloads = Join-Path $Root "downloads"
$VersionsFile = Join-Path $Root "versions.json"

function Parar($msg) {
    Write-Host ""
    Write-Host "ERRO: $msg" -ForegroundColor Red
    Write-Host ""
    Read-Host "Pressione ENTER para fechar"
    exit 1
}

function Get-VersionFromName($name, $regex) {
    $m = [regex]::Match($name, $regex)
    if(-not $m.Success){ return $null }
    try { return [version]$m.Groups[1].Value } catch { return $null }
}

function Get-LatestBuild($folders, $pattern, $versionRegex) {
    $items = @()
    foreach($folder in $folders){
        if(-not (Test-Path $folder)){ continue }
        try{
            $found = Get-ChildItem -Path $folder -File -Recurse -Filter $pattern -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.FullName -notlike "$Downloads*" -and
                    $_.FullName -notmatch '\\node_modules\\'
                }
            foreach($f in $found){
                $v = Get-VersionFromName $f.Name $versionRegex
                if($v){ $items += [PSCustomObject]@{ File=$f; Version=$v } }
            }
        }catch{}
    }
    return $items | Sort-Object Version -Descending | Select-Object -First 1
}

Set-Location $Root
Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   GESTOR PRO - ATUALIZAR SITE V7 AUTOMATICO" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path "$Root\index.html")) { Parar "index.html nao encontrado." }
if (!(Test-Path "$Root\assets")) { Parar "Pasta assets nao encontrada." }
if (!(Test-Path $Downloads)) { New-Item -ItemType Directory $Downloads | Out-Null }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { Parar "Git nao encontrado." }
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { Parar "GitHub CLI nao encontrado." }

Write-Host "[1/6] Procurando automaticamente as versoes mais novas..." -ForegroundColor White

# Procura os projetos ao lado do site na Area de Trabalho.
# IMPORTANTE: a pasta do projeto Windows pode se chamar apenas "PC",
# por isso nao limitamos mais a busca a pastas com nome Gestor-Pro*.
$Parent = Split-Path -Parent $Root

$SiblingFolders = Get-ChildItem -Path $Parent -Directory -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -ne $Root -and
        $_.Name -notmatch '^(node_modules|\.git|dist-android|downloads)$'
    } |
    Select-Object -ExpandProperty FullName

# Inclui a propria pasta do site e TODAS as pastas irmas.
# Assim encontra, por exemplo:
#   Desktop\PC\dist\Gestor-Pro-Setup-1.0.14.exe
#   Desktop\Gestor-Pro-Android-...\dist-android\Gestor-Pro-Android-0.2.17.apk
$SearchFolders = @($Root) + @($SiblingFolders)

$LatestWin = Get-LatestBuild $SearchFolders "Gestor-Pro-Setup-*.exe" '^Gestor-Pro-Setup-(\d+\.\d+\.\d+)\.exe$'
$LatestAndroid = Get-LatestBuild $SearchFolders "Gestor-Pro-Android-*.apk" '^Gestor-Pro-Android-(\d+\.\d+\.\d+)\.apk$'

if(-not $LatestWin){
    Parar "Nao encontrei nenhum Gestor-Pro-Setup-X.X.X.exe nas pastas do Gestor Pro."
}
if(-not $LatestAndroid){
    Parar "Nao encontrei nenhum Gestor-Pro-Android-X.X.X.apk nas pastas do Gestor Pro."
}

$WinName = $LatestWin.File.Name
$AndroidName = $LatestAndroid.File.Name
$WinVersion = $LatestWin.Version.ToString()
$AndroidVersion = $LatestAndroid.Version.ToString()

Write-Host "Windows encontrado: v$WinVersion  ($WinName)" -ForegroundColor Green
Write-Host "  Origem Windows: $($LatestWin.File.FullName)" -ForegroundColor DarkGray
Write-Host "Android encontrado: v$AndroidVersion  ($AndroidName)" -ForegroundColor Green
Write-Host "  Origem Android: $($LatestAndroid.File.FullName)" -ForegroundColor DarkGray

$WinDest = Join-Path $Downloads $WinName
$AndroidDest = Join-Path $Downloads $AndroidName

if($LatestWin.File.FullName -ne $WinDest){
    Copy-Item $LatestWin.File.FullName $WinDest -Force
}
if($LatestAndroid.File.FullName -ne $AndroidDest){
    Copy-Item $LatestAndroid.File.FullName $AndroidDest -Force
}

# Remove instaladores antigos do site para não crescer indefinidamente.
Get-ChildItem $Downloads -File -Filter "Gestor-Pro-Setup-*.exe" |
    Where-Object { $_.Name -ne $WinName } | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem $Downloads -File -Filter "Gestor-Pro-Android-*.apk" |
    Where-Object { $_.Name -ne $AndroidName } | Remove-Item -Force -ErrorAction SilentlyContinue

$Versions = [ordered]@{
    updatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    windows = [ordered]@{
        version = $WinVersion
        file = $WinName
    }
    android = [ordered]@{
        version = $AndroidVersion
        file = $AndroidName
    }
}
$Versions | ConvertTo-Json -Depth 4 | Set-Content $VersionsFile -Encoding UTF8

Write-Host ""
Write-Host "versions.json atualizado automaticamente." -ForegroundColor Cyan

Write-Host "[2/6] Verificando login no GitHub..."
cmd /c "gh auth status >nul 2>&1"
if ($LASTEXITCODE -ne 0) {
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { Parar "Falha no login do GitHub." }
}

Write-Host "[3/6] Preparando repositorio..."
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

Write-Host "[4/6] Preparando site, versoes e downloads..."
# Publica os arquivos do site. Mantemos os instaladores/pastas controlados
# e incluimos automaticamente arquivos web novos da raiz, como sitemap.xml,
# robots.txt, manifest.json, favicon.ico etc.
git add -f index.html
git add -f assets
git add -f downloads
git add -f versions.json
git add -f CNAME
git add -f .nojekyll

$RootWebPatterns = @(
    "*.html",
    "*.htm",
    "*.css",
    "*.js",
    "*.json",
    "*.xml",
    "*.txt",
    "*.ico",
    "*.webmanifest"
)

foreach($pattern in $RootWebPatterns){
    Get-ChildItem -Path $Root -File -Filter $pattern -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notlike "ATUALIZAR-SITE*" -and
            $_.Name -notlike "PUBLICAR-SITE*" -and
            $_.Name -notlike "README*" -and
            $_.Name -notlike "LEIA-ME*"
        } |
        ForEach-Object {
            git add -f -- $_.Name
        }
}

$changes = @(git diff --cached --name-only)
if ($changes.Count -eq 0) {
    Write-Host "Nenhuma diferenca detectada. Forcando novo deploy..." -ForegroundColor Yellow
    git commit --allow-empty -m "Forcar deploy Gestor PRO"
} else {
    Write-Host ""
    Write-Host "Arquivos que serao publicados:" -ForegroundColor Green
    $changes | ForEach-Object { Write-Host "  $_" }
    git commit -m "Atualizar site Gestor PRO - Windows $WinVersion Android $AndroidVersion"
}
if ($LASTEXITCODE -ne 0) { Parar "Falha ao criar commit." }

Write-Host "[5/6] Enviando para o GitHub..."
git push origin $Branch
if ($LASTEXITCODE -ne 0) { Parar "Falha ao enviar atualizacao." }

Write-Host "[6/6] Concluido."
Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   SITE E VERSOES ATUALIZADOS COM SUCESSO" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Windows no site: v$WinVersion" -ForegroundColor White
Write-Host "Android no site: v$AndroidVersion" -ForegroundColor White
Write-Host ""
Write-Host "Daqui para frente voce NAO precisa editar a versao no index.html." -ForegroundColor Cyan
Write-Host "O V7 procura os instaladores, cria versions.json e publica tambem arquivos web novos." -ForegroundColor Cyan
Write-Host ""
Write-Host "Aguarde 1 a 3 minutos e pressione CTRL + F5 no site." -ForegroundColor Yellow
Write-Host "https://gestorpro.log.br" -ForegroundColor Cyan
Write-Host ""
Read-Host "Pressione ENTER para fechar"
