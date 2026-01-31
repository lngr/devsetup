{
  "name": "{{PROJECT_NAME}}",
  "dockerComposeFile": {{COMPOSE_FILES}},
  "service": "dev",
  "workspaceFolder": "/workspaces/{{PROJECT_NAME}}",
  "runServices": {{RUN_SERVICES}},

  "initializeCommand": "bash ${localWorkspaceFolder}/.devcontainer/init-worktree.sh",

  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/eitsupi/devcontainer-features/jq-likes:2": {}
  },

  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code"
      ]
    }
  },
  "containerEnv": {
    "TZ": "{{TIMEZONE}}"
  },
  "remoteEnv": {
    "DISPLAY": "${localEnv:DISPLAY}",
    "XAUTHORITY": "/home/vscode/.Xauthority"
  },
  "postCreateCommand": "bash -lc 'bash .devcontainer/postCreateCommand.sh'",
  "postStartCommand": "bash -lc 'bash .devcontainer/postStartCommand.sh'",
  "remoteUser": "vscode"
}
