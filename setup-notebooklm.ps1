# =============================================================================
# Setup NotebookLM MCP para Claude Code (Windows — PowerShell)
# Proyecto: Comercial Express Plataforma
# =============================================================================
#Requires -Version 5.1

$ErrorActionPreference = "Stop"

function Write-Step  { param($msg) Write-Host "`n▶ $msg" -ForegroundColor Cyan -ForegroundColor White }
function Write-Ok    { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info  { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Warn  { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

Write-Host @"
╔══════════════════════════════════════════════════╗
║    NotebookLM MCP Setup — Comercial Express      ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# ─── PASO 1: Instalar uv ─────────────────────────────────────────────────────
Write-Step "1/5 — Verificando uv (gestor de paquetes Python)"

$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if ($uvCmd) {
    Write-Ok "uv ya instalado: $(uv --version)"
} else {
    Write-Info "Instalando uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:PATH"
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uvCmd) {
        Write-Fail "No se pudo instalar uv. Visita https://docs.astral.sh/uv/"
    }
    Write-Ok "uv instalado"
}

# ─── PASO 2: Instalar notebooklm-mcp-cli ─────────────────────────────────────
Write-Step "2/5 — Instalando notebooklm-mcp-cli"

$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

$nlmCmd = Get-Command nlm -ErrorAction SilentlyContinue
if ($nlmCmd) {
    Write-Info "Actualizando..."
    uv tool install --upgrade notebooklm-mcp-cli
} else {
    uv tool install notebooklm-mcp-cli
}

# Localizar ejecutables
$nlmPath = (Get-Command nlm -ErrorAction SilentlyContinue)?.Source
$mcpPath = (Get-Command notebooklm-mcp -ErrorAction SilentlyContinue)?.Source

if (-not $nlmPath) {
    # Buscar en rutas típicas de uv en Windows
    $possiblePaths = @(
        "$env:USERPROFILE\.local\bin\notebooklm-mcp.exe",
        "$env:APPDATA\Python\Scripts\notebooklm-mcp.exe",
        "$env:USERPROFILE\AppData\Roaming\Python\Scripts\notebooklm-mcp.exe"
    )
    foreach ($p in $possiblePaths) {
        if (Test-Path $p) { $mcpPath = $p; break }
    }
}

if (-not $mcpPath) {
    # Fallback: buscar con where
    $mcpPath = (& where.exe notebooklm-mcp 2>$null) | Select-Object -First 1
}

Write-Ok "nlm: $nlmPath"
Write-Ok "notebooklm-mcp: $mcpPath"

# ─── PASO 3: Autenticación ───────────────────────────────────────────────────
Write-Step "3/5 — Autenticación con Google NotebookLM"

$authOk = $false
try {
    $checkResult = & nlm login --check 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Ya autenticado"
        $authOk = $true
    }
} catch {}

if (-not $authOk) {
    Write-Info "Abriendo navegador para autenticación..."
    Write-Host "  → Inicia sesión con tu cuenta Google en la ventana del navegador." -ForegroundColor Yellow
    Write-Host "  → Las cookies se extraen automáticamente." -ForegroundColor Yellow
    try {
        & nlm login
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Autenticación completada"
            $authOk = $true
        }
    } catch {
        Write-Warn "Login automático falló. Opción manual:"
        Write-Host ""
        Write-Host "  1. Ve a https://notebooklm.google.com en Chrome"
        Write-Host "  2. Instala Cookie-Editor (extensión Chrome)"
        Write-Host "  3. Export → 'Export as Netscape HTTP Cookie File'"
        Write-Host "  4. Guarda como C:\Temp\notebooklm_cookies.txt"
        Write-Host "  5. Ejecuta: nlm login --manual --file C:\Temp\notebooklm_cookies.txt"
    }
}

# ─── PASO 4: Configurar MCP en Claude Code ───────────────────────────────────
Write-Step "4/5 — Configurando MCP server"

function Set-McpInSettings {
    param($SettingsFile, $McpBin)

    $dir = Split-Path $SettingsFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if (Test-Path $SettingsFile) {
        $content = Get-Content $SettingsFile -Raw | ConvertFrom-Json
    } else {
        $content = [PSCustomObject]@{}
    }

    if (-not $content.PSObject.Properties['mcpServers']) {
        $content | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{})
    }

    $mcpEntry = [PSCustomObject]@{ command = $McpBin }
    $content.mcpServers | Add-Member -NotePropertyName 'notebooklm' -NotePropertyValue $mcpEntry -Force

    $content | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    Write-Ok "Configurado: $SettingsFile"
}

# Claude Code (global)
$claudeSettings = Join-Path $env:USERPROFILE ".claude\settings.json"
Set-McpInSettings -SettingsFile $claudeSettings -McpBin $mcpPath

# Claude Desktop
$desktopConfig = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
if (Test-Path (Split-Path $desktopConfig -Parent)) {
    Write-Info "Claude Desktop detectado, configurando..."
    Set-McpInSettings -SettingsFile $desktopConfig -McpBin $mcpPath
}

# Usar nlm setup add también
Write-Info "Ejecutando nlm setup add claude-code..."
try { & nlm setup add claude-code 2>&1 } catch { Write-Warn "nlm setup add falló (ignorable)" }

# ─── PASO 5: Verificación ────────────────────────────────────────────────────
Write-Step "5/5 — Verificación final"
& nlm doctor

if ($authOk) {
    Write-Host ""
    Write-Info "Listando notebooks..."
    & nlm list notebooks
    Write-Host ""
    Write-Host "══════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Setup COMPLETO y OPERATIVO" -ForegroundColor Green
    Write-Host "══════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Próximos pasos:" -ForegroundColor White
    Write-Host "  1. Reinicia Claude Code"
    Write-Host "  2. Pide: 'busca el notebook Comercial Express'"
} else {
    Write-Warn "Falta autenticación. Ejecuta: nlm login"
}
