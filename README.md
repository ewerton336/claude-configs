# claude-configs

Sincroniza minha configuração do Claude Code (skills, plugins, settings, CLAUDE.md global) entre máquinas.

> Este repo é **espelho** de partes selecionadas de `~/.claude/`. Não inclui sessões, histórico, credenciais nem caches.

## Estrutura

```
config/
  settings.json       # ~/.claude/settings.json
  CLAUDE.md           # ~/.claude/CLAUDE.md (se existir)
skills/               # ~/.claude/skills/  (skills personalizadas)
plugins/
  installed_plugins.json
  known_marketplaces.json
scripts/
  sync-push.ps1       # ~/.claude → repo → GitHub
  sync-pull.ps1       # GitHub → repo → ~/.claude
```

## Setup numa máquina nova

1. Instale o Claude Code.
2. Clone o repo:
   ```powershell
   git clone https://github.com/ewerton336/claude-configs $HOME\claude-config
   ```
3. Aplique a config:
   ```powershell
   cd $HOME\claude-config
   .\scripts\sync-pull.ps1
   ```
4. Reinicie o Claude Code. Os marketplaces serão re-clonados automaticamente a partir de `known_marketplaces.json`. Para os plugins listados em `plugins/installed_plugins.json`, instale-os com `/plugin install <nome>` se não vierem automaticamente.

## Uso no dia-a-dia

**Atualizei skills/settings/plugins localmente — quero subir:**
```powershell
cd $HOME\claude-config
.\scripts\sync-push.ps1
```
Copia o estado atual de `~/.claude/`, comita e dá push.

**Quero pegar mudanças que fiz na outra máquina:**
```powershell
cd $HOME\claude-config
.\scripts\sync-pull.ps1
```
Faz `git pull`, gera backup do estado atual em `~/.claude/backups/<timestamp>/` e aplica a config do repo.

## O que NÃO é sincronizado

`.credentials.json`, `sessions/`, `history.jsonl`, `cache/`, `backups/`, `debug/`, `telemetry/`, `file-history/`, `paste-cache/`, `projects/`, `shell-snapshots/`, `plugins/cache/`, `plugins/data/`, `plugins/marketplaces/`, `tasks/`, `plans/`. Veja `.gitignore`.
