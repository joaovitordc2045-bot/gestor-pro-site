$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoName = "gestor-pro-site"
$Domain = "gestorpro.log.br"
$ExpectedOwner = "joaovitordc2045-bot"

function Info($m) { Write-Host $m -ForegroundColor Cyan }
function Ok($m)   { Write-Host $m -ForegroundColor Green }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Fail($m) {
    Write-Host ""
    Write-Host "ERRO: $m" -ForegroundColor Red
    Write-Host ""
    Read-Host "Pressione ENTER para fechar"
    exit 1
}

Set-Location $Root
$env:GH_PAGER = "cat"
$env:GIT_PAGER = "cat"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "     GESTOR PRO - PUBLICACAO AUTOMATICA DO SITE" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Dominio: $Domain"
Write-Host "Repositorio: $ExpectedOwner/$RepoName"
Write-Host ""

# ---------------------------------------------------------
# 1. GitHub CLI
# ---------------------------------------------------------
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Warn "GitHub CLI nao encontrado. Instalando automaticamente..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Fail "O winget nao esta disponivel. Instale o GitHub CLI e execute novamente."
    }
    winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Fail "Falha ao instalar o GitHub CLI." }

    $candidate = Join-Path $env:ProgramFiles "GitHub CLI"
    if (Test-Path $candidate) { $env:Path = "$candidate;$env:Path" }
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "GitHub CLI instalado, mas nao foi localizado. Feche esta janela e execute PUBLICAR-SITE.bat novamente."
}

# ---------------------------------------------------------
# 2. Git
# ---------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Warn "Git nao encontrado. Instalando automaticamente..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Fail "O winget nao esta disponivel. Instale o Git e execute novamente."
    }
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Fail "Falha ao instalar o Git." }

    $gitCmd = Join-Path $env:ProgramFiles "Git\cmd"
    if (Test-Path $gitCmd) { $env:Path = "$gitCmd;$env:Path" }
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git instalado, mas nao foi localizado. Feche esta janela e execute PUBLICAR-SITE.bat novamente."
}

# ---------------------------------------------------------
# 3. Login GitHub
# ---------------------------------------------------------
Info "Verificando autorizacao do GitHub..."
& gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Warn "Este computador ainda nao esta autenticado no GitHub CLI."
    Write-Host "Uma pagina do GitHub sera aberta para autorizar."
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { Fail "Nao foi possivel autenticar no GitHub." }
}

$Owner = (& gh api user --jq ".login" | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($Owner)) { Fail "Nao consegui identificar a conta do GitHub." }

Write-Host "Conta conectada: $Owner"
if ($Owner -ne $ExpectedOwner) {
    Warn "ATENCAO: a conta conectada e '$Owner', mas este pacote foi preparado para '$ExpectedOwner'."
    $resp = Read-Host "Deseja publicar mesmo assim nessa conta? (S/N)"
    if ($resp -notmatch '^(s|sim|y|yes)$') { exit 0 }
}
$Repo = "$Owner/$RepoName"

# ---------------------------------------------------------
# 4. Arquivos obrigatorios
# ---------------------------------------------------------
if (-not (Test-Path (Join-Path $Root "index.html"))) {
    Fail "index.html nao foi encontrado na pasta."
}
Set-Content -Path (Join-Path $Root "CNAME") -Value $Domain -Encoding ascii -NoNewline
if (-not (Test-Path (Join-Path $Root ".nojekyll"))) {
    New-Item -ItemType File -Path (Join-Path $Root ".nojekyll") | Out-Null
}

# ---------------------------------------------------------
# 5. Repo GitHub
# ---------------------------------------------------------
Info "Preparando repositorio $Repo..."

& gh repo view $Repo *> $null
$RepoExists = ($LASTEXITCODE -eq 0)

if (-not $RepoExists) {
    Info "Criando repositorio publico..."
    & gh repo create $Repo --public --description "Site oficial do Gestor PRO - Windows e Android"
    if ($LASTEXITCODE -ne 0) { Fail "Nao foi possivel criar o repositorio $Repo." }
    Ok "Repositorio criado."
} else {
    Ok "Repositorio ja existe. Vou apenas atualizar o site."
}

# ---------------------------------------------------------
# 6. Git local
# ---------------------------------------------------------
if (-not (Test-Path (Join-Path $Root ".git"))) {
    git init | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "Falha ao iniciar o Git nesta pasta." }
}

git checkout -B main | Out-Null

# Configure identity locally if missing.
$email = (git config user.email 2>$null | Out-String).Trim()
$name  = (git config user.name 2>$null | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($email)) { git config user.email "joaovitordc1010@gmail.com" }
if ([string]::IsNullOrWhiteSpace($name))  { git config user.name "Gestor PRO" }

$remoteUrl = "https://github.com/$Repo.git"
$origin = (git remote 2>$null | Out-String)
if ($origin -match '(^|\s)origin(\s|$)') {
    git remote set-url origin $remoteUrl
} else {
    git remote add origin $remoteUrl
}

# Do not upload local helper/zip files.
$gitignore = @"
.git/
*.zip
*.log
PUBLICAR-SITE.ps1
PUBLICAR-SITE.bat
CONFIGURAR-DNS-REGISTROBR.txt
ABRIR-DNS-REGISTROBR.bat
VERIFICAR-SITE.bat
README-PUBLICACAO.txt
downloads/COLOQUE-OS-INSTALADORES-AQUI.txt
"@
Set-Content -Path (Join-Path $Root ".gitignore") -Value $gitignore -Encoding utf8

Info "Enviando arquivos do site para o GitHub..."
git add -A
git diff --cached --quiet
$HasChanges = ($LASTEXITCODE -ne 0)

if ($HasChanges) {
    git commit -m "Atualizar site oficial Gestor PRO" | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "Falha ao criar o commit do site." }
} else {
    Write-Host "Nenhuma alteracao nova nos arquivos locais."
}

# If remote already has main and local history is fresh/unrelated, first synchronize safely.
git ls-remote --exit-code --heads origin main *> $null
$RemoteMainExists = ($LASTEXITCODE -eq 0)

if ($RemoteMainExists) {
    git fetch origin main | Out-Null
    # If histories are related, rebase. Otherwise only use force-with-lease for this dedicated site repo.
    git merge-base HEAD origin/main *> $null
    if ($LASTEXITCODE -eq 0) {
        git rebase origin/main
        if ($LASTEXITCODE -ne 0) {
            git rebase --abort 2>$null
            Fail "Houve conflito ao sincronizar o repositorio. Nenhum arquivo remoto foi apagado."
        }
        git push -u origin main
    } else {
        Warn "O repositorio remoto possui historico diferente. Como ele e dedicado ao site, vou sincronizar usando force-with-lease."
        git push -u origin main --force-with-lease
    }
} else {
    git push -u origin main
}
if ($LASTEXITCODE -ne 0) { Fail "Falha ao enviar os arquivos para o GitHub." }
Ok "Arquivos enviados com sucesso."

# ---------------------------------------------------------
# 7. GitHub Pages
# ---------------------------------------------------------
Info "Ativando GitHub Pages..."

& gh api "repos/$Repo/pages" *> $null
$PagesExists = ($LASTEXITCODE -eq 0)

$bodyPath = Join-Path $env:TEMP "gestorpro-pages.json"

if (-not $PagesExists) {
    '{"source":{"branch":"main","path":"/"}}' | Set-Content -Path $bodyPath -Encoding ascii
    & gh api --method POST -H "Accept: application/vnd.github+json" "repos/$Repo/pages" --input $bodyPath *> $null
    if ($LASTEXITCODE -ne 0) {
        # Sometimes GitHub needs a moment after first push.
        Start-Sleep -Seconds 4
        & gh api --method POST -H "Accept: application/vnd.github+json" "repos/$Repo/pages" --input $bodyPath *> $null
        if ($LASTEXITCODE -ne 0) { Fail "Os arquivos foram enviados, mas nao consegui ativar o GitHub Pages automaticamente." }
    }
    Ok "GitHub Pages ativado."
}

# Set custom domain and branch source.
$escapedDomain = $Domain.Replace('"','\"')
("{""cname"":""$escapedDomain"",""source"":{""branch"":""main"",""path"":""/""}}") | Set-Content -Path $bodyPath -Encoding ascii
& gh api --method PUT -H "Accept: application/vnd.github+json" "repos/$Repo/pages" --input $bodyPath *> $null
if ($LASTEXITCODE -ne 0) {
    Warn "Site publicado, mas o dominio personalizado pode precisar ser salvo manualmente no GitHub Pages."
} else {
    Ok "Dominio personalizado configurado no GitHub: $Domain"
}
Remove-Item $bodyPath -ErrorAction SilentlyContinue

# Trigger an explicit Pages build when supported.
& gh api --method POST "repos/$Repo/pages/builds" *> $null
Start-Sleep -Seconds 2

$DefaultUrl = "https://$Owner.github.io/$RepoName/"
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "   ETAPA GITHUB CONCLUIDA COM SUCESSO" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Repositorio: https://github.com/$Repo"
Write-Host "Endereco temporario: $DefaultUrl"
Write-Host "Dominio final: https://$Domain"
Write-Host ""
Warn "FALTA APENAS UMA CONFIGURACAO UNICA NO REGISTRO.BR:"
Write-Host "Adicione os 4 registros A abaixo na zona DNS:"
Write-Host ""
Write-Host "  A   @   185.199.108.153"
Write-Host "  A   @   185.199.109.153"
Write-Host "  A   @   185.199.110.153"
Write-Host "  A   @   185.199.111.153"
Write-Host ""
Write-Host "Vou abrir o Registro.br e o arquivo com as instrucoes."
Write-Host ""

Start-Process "https://registro.br/painel/dominios/"
Start-Process notepad.exe (Join-Path $Root "CONFIGURAR-DNS-REGISTROBR.txt")

Read-Host "Depois de configurar o DNS, pressione ENTER"
Write-Host ""
Info "Verificando DNS..."

try {
    $ips = Resolve-DnsName $Domain -Type A -ErrorAction Stop | Where-Object {$_.IPAddress} | Select-Object -ExpandProperty IPAddress
    $expected = @("185.199.108.153","185.199.109.153","185.199.110.153","185.199.111.153")
    $found = @($ips | Where-Object { $expected -contains $_ })
    if ($found.Count -gt 0) {
        Ok "DNS ja esta apontando para o GitHub Pages."
        Start-Process "https://$Domain"
    } else {
        Warn "A alteracao ainda nao apareceu no DNS. Isso e normal: a propagacao pode levar algum tempo."
        Write-Host "O site no GitHub ja esta publicado."
        Start-Process $DefaultUrl
    }
} catch {
    Warn "O DNS ainda nao respondeu com os novos registros. Isso e normal logo apos salvar."
    Start-Process $DefaultUrl
}

Write-Host ""
Write-Host "Nas proximas atualizacoes do site, basta executar PUBLICAR-SITE.bat novamente." -ForegroundColor Cyan
Write-Host ""
Read-Host "Pressione ENTER para fechar"
