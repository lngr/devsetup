# devsetup

Interaktives CLI-Tool, das in einem beliebigen Projektverzeichnis ein komplettes Dev-Container-Setup scaffolded. Nach dem Scaffolding ist das Setup self-contained -- keine Abhaengigkeit zum Tool.

## Installation

```bash
# Option 1: install.sh
./install.sh

# Option 2: Self-install
./devsetup.sh --install
```

Beide Varianten erstellen einen Symlink `~/.local/bin/devsetup` -> `devsetup.sh`.
Sicherstellen, dass `~/.local/bin` im `PATH` liegt:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Verwendung

```bash
# Im Projektverzeichnis ausfuehren
cd ~/mein-projekt
devsetup

# Oder mit explizitem Zielverzeichnis
devsetup --target ~/mein-projekt
```

Das Tool fuehrt einen interaktiven Prompt-Flow durch:

1. **Projektname** -- Default: Verzeichnisname (sanitized fuer Docker Compose)
2. **Git-Modus**
   - *Read-only* -- `.git` wird als `:ro` gemountet, Worktrees auf dem Host, pro Worktree ein eigener Container-Stack
   - *Writable* -- Voller Git-Zugriff im Container, ein Container fuer alles
3. **Base-Image** -- Ubuntu Noble, Node.js 22, .NET 8/9, Python 3, Go, oder Custom
4. **Services** -- Mehrfachauswahl aus PostgreSQL+PgAdmin, Redis, RabbitMQ, MySQL+phpMyAdmin, MinIO, MongoDB
5. **Timezone** -- Default: `Europe/Berlin`
6. **Zusammenfassung** -- Bestaetigung vor der Generierung

## Generierte Dateien

```
projekt/
├── .devcontainer/
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── docker-compose.services.yml    # nur bei ausgewaehlten Services
│   ├── Dockerfile
│   ├── .env
│   ├── devsetup.conf                  # persistierte Config
│   ├── init-worktree.sh
│   ├── postCreateCommand.sh
│   ├── postStartCommand.sh
│   ├── scripts/
│   │   ├── install-agents.sh
│   │   └── update-agents.sh
│   └── postgres-init/                 # nur bei PostgreSQL
│       └── 01-create-databases.sh
└── exec-devcontainer.sh               # Entry-Script
```

## Container starten

```bash
cd ~/mein-projekt
./exec-devcontainer.sh
```

Das Script:
- Installiert `@devcontainers/cli` falls noetig
- Fuehrt `init-worktree.sh` aus (setzt `COMPOSE_PROJECT_NAME`)
- Konfiguriert X11-Forwarding (Linux nativ, TCP-Fallback fuer IntelliJ)
- Startet den Container via `devcontainer up`
- Synct `~/.tmux.conf` in den Container
- Oeffnet eine Shell als `vscode`-User

Alternativ mit VS Code:
```
Ctrl+Shift+P -> "Dev Containers: Reopen in Container"
```

## Coding Agents

Folgende Agents werden automatisch installiert (`postCreateCommand.sh`) und bei jedem Start aktualisiert (`postStartCommand.sh`):

| Agent | Befehl im Container |
|---|---|
| Claude Code | `claude` (mit `--dangerously-skip-permissions --ide`) |
| OpenAI Codex | `codex` (mit `--dangerously-bypass-approvals-and-sandbox`) |
| OpenCode | `opencode` |

Die Aliases sind in `~/.bashrc` und `~/.zshrc` hinterlegt. API-Keys sind nicht noetig -- die Agents nutzen OAuth-Login beim ersten Aufruf.

## Git-Modi im Detail

### Read-only (empfohlen fuer Worktree-Workflows)

```yaml
volumes:
  - ..:/workspaces/projekt
  - ../.git:/workspaces/projekt/.git:ro
```

- Agents koennen `git log`, `git diff`, `git blame` lesen
- Kein Commit/Push aus dem Container
- Worktrees auf dem Host erstellen: `git worktree add ../feature-x`
- Jeder Worktree bekommt eigenen Container-Stack mit eigenen Volumes

### Writable

```yaml
volumes:
  - ..:/workspaces/projekt    # inkl. .git rw
```

- Voller Git-Zugriff (commit, push, branch, worktree)
- Ein Container fuer das gesamte Projekt
- `.gitconfig` vom Host gemountet

## Services

Ausgewaehlte Services werden in `docker-compose.services.yml` konfiguriert. Im Container sind sie ueber `socat`-Port-Forwards auf `localhost` erreichbar:

| Service | Port im Container |
|---|---|
| PostgreSQL | 5432 |
| Redis | 6379 |
| RabbitMQ | 5672 |
| MySQL | 3306 |
| MongoDB | 27017 |

PgAdmin, phpMyAdmin und MinIO Console sind ueber ihre jeweiligen Ports erreichbar (5050, 80, 9001).

## X11 / Clipboard

Der Container hat X11-Support fuer Clipboard-Zugriff (`xclip`, `xsel`). Auf Linux wird der X11-Socket direkt gemountet. Fuer IntelliJ-Container ohne Socket-Mount wird automatisch ein TCP-Forward via `socat` eingerichtet.

## Projektstruktur (Tool)

```
devsetup/
├── devsetup.sh              # Hauptskript
├── install.sh               # Symlink-Erstellung
├── lib/
│   ├── prompts.sh           # Interaktive Prompts
│   └── templates.sh         # {{VAR}}-Template-Engine
└── templates/
    ├── devcontainer.json.tpl
    ├── docker-compose.yml.tpl
    ├── docker-compose.services.yml.tpl
    ├── Dockerfile.tpl
    ├── exec-devcontainer.sh.tpl
    ├── init-worktree.sh.tpl
    ├── postCreateCommand.sh.tpl
    ├── postStartCommand.sh.tpl
    ├── scripts/
    │   ├── install-agents.sh.tpl
    │   └── update-agents.sh.tpl
    └── services/
        ├── postgres.yml.tpl
        ├── pgadmin.yml.tpl
        ├── redis.yml.tpl
        ├── rabbitmq.yml.tpl
        ├── mysql.yml.tpl
        ├── phpmyadmin.yml.tpl
        ├── minio.yml.tpl
        └── mongodb.yml.tpl
```
