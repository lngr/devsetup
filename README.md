# devsetup

Interactive CLI tool that scaffolds a complete dev container setup in any project directory. After scaffolding, the setup is self-contained -- no dependency on the tool.

## Installation

```bash
# Option 1: install.sh
./install.sh

# Option 2: Self-install
./devsetup.sh --install
```

Both options create a symlink `~/.local/bin/devsetup` -> `devsetup.sh`.
Make sure `~/.local/bin` is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

```bash
# Run in the project directory
cd ~/my-project
devsetup

# Or with an explicit target directory
devsetup --target ~/my-project
```

The tool guides you through an interactive prompt flow:

1. **Project name** -- Default: directory name (sanitized for Docker Compose)
2. **Git mode**
   - *Read-only* -- `.git` is mounted as `:ro`, worktrees on the host, each worktree gets its own container stack
   - *Writable* -- Full git access inside the container, one container for everything
3. **Base image** -- Ubuntu Noble, Node.js 22, .NET 8/9, Python 3, Go, or Custom
4. **Services** -- Multi-select from PostgreSQL+PgAdmin, Redis, RabbitMQ, MySQL+phpMyAdmin, MinIO, MongoDB
5. **Timezone** -- Default: `Europe/Berlin`
6. **Summary** -- Confirmation before generation

## Generated Files

```
project/
├── .devcontainer/
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── docker-compose.services.yml    # only when services are selected
│   ├── Dockerfile
│   ├── .env
│   ├── devsetup.conf                  # persisted config
│   ├── init-worktree.sh
│   ├── postCreateCommand.sh
│   ├── postStartCommand.sh
│   ├── scripts/
│   │   ├── install-agents.sh
│   │   └── update-agents.sh
│   └── postgres-init/                 # only with PostgreSQL
│       └── 01-create-databases.sh
└── exec-devcontainer.sh               # entry script
```

## Starting the Container

```bash
cd ~/my-project
./exec-devcontainer.sh
```

The script:
- Installs `@devcontainers/cli` if needed
- Runs `init-worktree.sh` (sets `COMPOSE_PROJECT_NAME`)
- Configures X11 forwarding (native on Linux, TCP fallback for IntelliJ)
- Starts the container via `devcontainer up`
- Syncs `~/.tmux.conf` into the container
- Opens a shell as the `vscode` user

Alternatively with VS Code:
```
Ctrl+Shift+P -> "Dev Containers: Reopen in Container"
```

## Coding Agents

The following agents are automatically installed (`postCreateCommand.sh`) and updated on every start (`postStartCommand.sh`):

| Agent | Command in Container |
|---|---|
| Claude Code | `claude` (with `--dangerously-skip-permissions --ide`) |
| OpenAI Codex | `codex` (with `--dangerously-bypass-approvals-and-sandbox`) |
| OpenCode | `opencode` |

The aliases are configured in `~/.bashrc` and `~/.zshrc`. No API keys required -- the agents use OAuth login on first invocation.

## Git Modes in Detail

### Read-only (recommended for worktree workflows)

```yaml
volumes:
  - ..:/workspaces/project
  - ../.git:/workspaces/project/.git:ro
```

- Agents can read `git log`, `git diff`, `git blame`
- No commit/push from inside the container
- Create worktrees on the host: `git worktree add ../feature-x`
- Each worktree gets its own container stack with separate volumes

### Writable

```yaml
volumes:
  - ..:/workspaces/project    # incl. .git rw
```

- Full git access (commit, push, branch, worktree)
- One container for the entire project
- `.gitconfig` mounted from the host

## Services

Selected services are configured in `docker-compose.services.yml`. Inside the container, they are accessible on `localhost` via `socat` port forwards:

| Service | Port in Container |
|---|---|
| PostgreSQL | 5432 |
| Redis | 6379 |
| RabbitMQ | 5672 |
| MySQL | 3306 |
| MongoDB | 27017 |

PgAdmin, phpMyAdmin, and MinIO Console are accessible on their respective ports (5050, 80, 9001).

## X11 / Clipboard

The container has X11 support for clipboard access (`xclip`, `xsel`). On Linux, the X11 socket is mounted directly. For IntelliJ containers without socket mount, a TCP forward via `socat` is set up automatically.

## Project Structure (Tool)

```
devsetup/
├── devsetup.sh              # main script
├── install.sh               # symlink creation
├── lib/
│   ├── prompts.sh           # interactive prompts
│   └── templates.sh         # {{VAR}} template engine
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
