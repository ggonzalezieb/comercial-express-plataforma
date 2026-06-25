#!/usr/bin/env bash
# =============================================================================
# Setup NotebookLM MCP para Claude Code (Mac/Linux)
# Proyecto: Comercial Express Plataforma
# =============================================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $1${NC}"; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║    NotebookLM MCP Setup — Comercial Express      ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Detectar OS ─────────────────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
info "Sistema detectado: $OS / $ARCH"

# ─── PASO 1: Instalar uv ─────────────────────────────────────────────────────
step "1/5 — Verificando uv (gestor de paquetes Python)"

if command -v uv &>/dev/null; then
    UV_VERSION=$(uv --version 2>&1)
    success "uv ya instalado: $UV_VERSION"
else
    info "Instalando uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Recargar PATH
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    source "$HOME/.cargo/env" 2>/dev/null || true
    if command -v uv &>/dev/null; then
        success "uv instalado correctamente"
    else
        error "No se pudo instalar uv. Visita https://docs.astral.sh/uv/getting-started/installation/"
    fi
fi

# ─── PASO 2: Instalar notebooklm-mcp-cli ─────────────────────────────────────
step "2/5 — Instalando notebooklm-mcp-cli"

export PATH="$HOME/.local/bin:$PATH"

if command -v nlm &>/dev/null; then
    CURRENT=$(nlm --version 2>&1 | head -1)
    info "Versión actual: $CURRENT"
    info "Actualizando a la última versión..."
    uv tool install --upgrade notebooklm-mcp-cli 2>&1 | tail -3
else
    info "Instalando notebooklm-mcp-cli..."
    uv tool install notebooklm-mcp-cli 2>&1 | tail -5
fi

# Verificar ejecutables
NLM_PATH=$(command -v nlm 2>/dev/null || echo "$HOME/.local/bin/nlm")
MCP_PATH=$(command -v notebooklm-mcp 2>/dev/null || echo "$HOME/.local/bin/notebooklm-mcp")

if [ ! -f "$NLM_PATH" ]; then
    error "nlm no encontrado en PATH. Asegúrate de que ~/.local/bin esté en tu PATH."
fi
success "nlm: $NLM_PATH"
success "notebooklm-mcp: $MCP_PATH"

# ─── PASO 3: Autenticación ───────────────────────────────────────────────────
step "3/5 — Autenticación con Google NotebookLM"

# Verificar si ya está autenticado
AUTH_OK=false
if nlm login --check &>/dev/null 2>&1; then
    success "Ya autenticado con NotebookLM"
    AUTH_OK=true
else
    # Intentar login automático con navegador
    info "Abriendo NotebookLM en tu navegador para autenticación..."
    echo ""
    echo -e "${YELLOW}  → Se abrirá el navegador. Inicia sesión con tu cuenta Google.${NC}"
    echo -e "${YELLOW}  → Las cookies se extraen automáticamente al completar el login.${NC}"
    echo ""

    if nlm login 2>&1; then
        success "Autenticación completada"
        AUTH_OK=true
    else
        warn "Login automático falló. Intentando modo manual..."
        echo ""
        echo -e "${YELLOW}Modo manual: Necesitas exportar las cookies de NotebookLM.${NC}"
        echo ""
        echo "  1. Abre https://notebooklm.google.com en Chrome"
        echo "  2. Instala la extensión 'Cookie-Editor'"
        echo "  3. Click en Cookie-Editor → Export → 'Export as Netscape HTTP Cookie File'"
        echo "  4. Guarda el archivo como: /tmp/notebooklm_cookies.txt"
        echo ""
        read -p "¿Ya guardaste el archivo de cookies? (s/n): " RESP
        if [[ "$RESP" =~ ^[sS]$ ]]; then
            COOKIE_FILE="${1:-/tmp/notebooklm_cookies.txt}"
            if [ -f "$COOKIE_FILE" ]; then
                nlm login --manual --file "$COOKIE_FILE" && AUTH_OK=true
            else
                error "Archivo no encontrado: $COOKIE_FILE"
            fi
        else
            warn "Autenticación omitida. Ejecuta 'nlm login' manualmente después."
        fi
    fi
fi

# ─── PASO 4: Configurar MCP en Claude Code / Claude Desktop ──────────────────
step "4/5 — Configurando MCP server en Claude Code"

# Claude Code (settings globales)
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

configure_mcp_in_settings() {
    local SETTINGS_FILE="$1"
    local MCP_BIN="$2"

    if [ -f "$SETTINGS_FILE" ]; then
        # Archivo existe — agregar/actualizar mcpServers
        CURRENT=$(cat "$SETTINGS_FILE")
        # Verificar si ya tiene notebooklm
        if echo "$CURRENT" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'notebooklm' in d.get('mcpServers',{}) else 1)" 2>/dev/null; then
            info "MCP 'notebooklm' ya configurado en $SETTINGS_FILE"
            # Actualizar el path por si cambió
            python3 -c "
import json, sys
with open('$SETTINGS_FILE') as f: d = json.load(f)
d.setdefault('mcpServers', {})['notebooklm'] = {'command': '$MCP_BIN'}
with open('$SETTINGS_FILE', 'w') as f: json.dump(d, f, indent=2)
print('Path actualizado.')
"
        else
            # Agregar el servidor
            python3 -c "
import json, sys
with open('$SETTINGS_FILE') as f: d = json.load(f)
d.setdefault('mcpServers', {})['notebooklm'] = {'command': '$MCP_BIN'}
with open('$SETTINGS_FILE', 'w') as f: json.dump(d, f, indent=2)
print('Servidor MCP agregado.')
"
        fi
    else
        # Crear archivo nuevo
        python3 -c "
import json
d = {'mcpServers': {'notebooklm': {'command': '$MCP_BIN'}}}
with open('$SETTINGS_FILE', 'w') as f: json.dump(d, f, indent=2)
print('Archivo creado.')
"
    fi
    success "Configurado: $SETTINGS_FILE"
}

configure_mcp_in_settings "$CLAUDE_SETTINGS" "$MCP_PATH"

# Claude Desktop (si está instalado)
if [[ "$OS" == "Darwin" ]]; then
    DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
elif [[ "$OS" == "Linux" ]]; then
    DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
else
    DESKTOP_CONFIG=""
fi

if [ -n "$DESKTOP_CONFIG" ] && [ -d "$(dirname "$DESKTOP_CONFIG")" ]; then
    info "Claude Desktop detectado, configurando..."
    configure_mcp_in_settings "$DESKTOP_CONFIG" "$MCP_PATH"
else
    info "Claude Desktop no detectado (normal si usas solo Claude Code CLI)"
fi

# Usar el comando automático de nlm también
info "Usando nlm setup add claude-code..."
nlm setup add claude-code 2>&1 || warn "nlm setup add claude-code falló (puede ignorarse si ya se configuró manualmente)"

# ─── PASO 5: Verificación final ──────────────────────────────────────────────
step "5/5 — Verificación final"

nlm doctor 2>&1

echo ""
if $AUTH_OK; then
    info "Listando notebooks para verificar conectividad..."
    if nlm list notebooks 2>&1; then
        echo ""
        success "══════════════════════════════════════════"
        success "  Setup COMPLETO y OPERATIVO"
        success "══════════════════════════════════════════"
        echo ""
        echo -e "${BOLD}Próximos pasos:${NC}"
        echo "  1. Reinicia Claude Code CLI para cargar el MCP server"
        echo "  2. En Claude, escribe: 'busca el notebook Comercial Express'"
        echo "  3. Para gestionar notebooks: nlm list notebooks"
        echo ""
    else
        warn "Lista de notebooks falló. Puede ser problema de red o sesión expirada."
        warn "Ejecuta 'nlm login' para re-autenticar."
    fi
else
    warn "Setup incompleto — falta autenticación."
    echo "  Ejecuta: nlm login"
fi

echo -e "${CYAN}Documentación: https://github.com/jacob-bd/notebooklm-mcp-cli${NC}"
