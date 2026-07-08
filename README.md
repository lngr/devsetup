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
2. **Workspace mount** -- Only this repo, or the parent directory so neighbouring repos and worktrees are visible
3. **Container scope** -- Only asked at parent mount: one shared container for all worktrees, or a separate container per worktree
4. **Claude config sharing** -- Bind-mount `~/.claude` live into the container
5. **Base image** -- Ubuntu Noble, Node.js 22, .NET 8/9, Python 3, Go, or Custom
6. **Services** -- Multi-select from PostgreSQL+PgAdmin, Redis, RabbitMQ, MySQL+phpMyAdmin, MinIO, MongoDB
7. **Timezone** -- Default: `Europe/Berlin`
8. **Docker-in-Docker** -- None, privileged, or Sysbox
9. **Summary** -- Confirmation before generation

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
- Runs `init-worktree.sh` (sets `COMPOSE_PROJECT_NAME` and records the host identity)
- Configures X11 forwarding (native on Linux, TCP fallback for IntelliJ)
- Starts the container via `devcontainer up`
- Opens a shell as your host user (same name, UID and home path as on the host)

Alternatively with VS Code:
```
Ctrl+Shift+P -> "Dev Containers: Reopen in Container"
```

## Coding Agents

The following agents are automatically installed (`postCreateCommand.sh`) and updated on every start (`postStartCommand.sh`):

| Agent | Command in Container |
|---|---|
| Claude Code | `claude` (with `--dangerously-skip-permissions --ide --chrome`) |
| OpenAI Codex | `codex` (with `--dangerously-bypass-approvals-and-sandbox`) |
| OpenCode | `opencode` |

The aliases are configured in `~/.bashrc` and `~/.zshrc`. No API keys required -- the agents use OAuth login on first invocation.

## Sharing the Claude Config

New setups default to `CLAUDE_CONFIG_MODE=share`. In this mode `exec-devcontainer`
bind-mounts the full `~/.claude` directory and `~/.claude.json` live (read-write)
into the container. Memories, skills, commands, settings, plugins and the OAuth
credentials are therefore shared with the host -- changes (e.g. a token refresh or
a newly written memory) flow straight back.

The setting lives in the user-local, gitignored `.devcontainer/devsetup.local.conf`
and is chosen when running `devsetup`. Toggle it per project at any time:

```
devsetup --disable-claude-share [<dir>]   # opt out
devsetup --enable-claude-share  [<dir>]   # opt back in
```

`exec-devcontainer` only consumes whatever the config says, so existing projects
are never changed implicitly.

> **Security note:** Sharing gives the container full read-write access to
> `~/.claude` including `~/.claude/.credentials.json`. For containers running
> untrusted code, disable sharing with `--disable-claude-share`.

## Workspace Mount and Container Scope

Two independent settings decide how the workspace is mounted and how containers map to worktrees.

### Workspace mount

Chosen during `devsetup` (`WORKSPACE_MOUNT` in `devsetup.conf`):

- `project`: only this repository is mounted at `/workspaces/<name>`.
- `parent`: the parent directory is mounted at `/workspaces`, so neighbouring repos and worktrees are visible in one mount.

`.git` is part of the workspace mount and has full read-write access.

### Container scope

`CONTAINER_SCOPE` decides whether worktrees share one container or each gets its own. It is only configurable at `parent` mount; `project` mount always uses a separate container per directory.

- `shared`: one container for all worktrees and branches. `COMPOSE_PROJECT_NAME` is `devcontainer-<project>`.
- `per-worktree`: each worktree directory gets its own container. `COMPOSE_PROJECT_NAME` is `devcontainer-<project>`, plus the directory name as a suffix when it differs from the project name.

`init-worktree.sh` writes the resulting `COMPOSE_PROJECT_NAME` into `.devcontainer/.env` on every start.

### Per-start override

With `parent` mount the scope can be overridden for a single launch:

- `exec-devcontainer --isolated` (alias `--own-container`): run this worktree in its own container.
- `exec-devcontainer --shared`: run in the shared project container.

Create worktrees on the host, e.g. `git worktree add ../feature-x`.

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
