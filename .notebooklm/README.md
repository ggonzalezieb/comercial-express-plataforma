# NotebookLM MCP — Comercial Express

Setup para usar NotebookLM desde Claude Code localmente.

## Instalación rápida (un comando)

**Mac/Linux:**
```bash
bash setup-notebooklm.sh
```

**Windows (PowerShell como administrador):**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\setup-notebooklm.ps1
```

## Qué hace el script

1. Instala `uv` si no está presente
2. Instala `notebooklm-mcp-cli` v0.7.7+
3. Abre el navegador para login con Google
4. Configura el MCP en `~/.claude/settings.json`
5. Verifica la conexión listando notebooks

## Después de instalar

Reinicia Claude Code y ya puedes pedir:
- *"Lista mis notebooks de NotebookLM"*
- *"¿Existe un notebook llamado Comercial Express?"*
- *"Crea un notebook sobre ventas y agrega esta URL..."*

## Rutas de configuración por OS

| OS | Claude Code | Claude Desktop |
|---|---|---|
| Mac | `~/.claude/settings.json` | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Linux | `~/.claude/settings.json` | `~/.config/Claude/claude_desktop_config.json` |
| Windows | `%USERPROFILE%\.claude\settings.json` | `%APPDATA%\Claude\claude_desktop_config.json` |

## Renovar sesión (cookies expiran en 2-4 semanas)

```bash
nlm login
```

## Diagnóstico

```bash
nlm doctor
nlm login --check
nlm list notebooks
```
