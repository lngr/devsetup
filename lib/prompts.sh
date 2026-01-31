#!/usr/bin/env bash
# prompts.sh – Interactive prompt helpers for devsetup

# Print a section header
prompt_header() {
  printf '\n\033[1;36m── %s ──\033[0m\n' "$1"
}

# Ask for text input with a default value
# Usage: prompt_input "Prompt text" DEFAULT_VALUE
# Sets REPLY
prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default"
  else
    printf '%s: ' "$prompt"
  fi
  read -r REPLY
  REPLY="${REPLY:-$default}"
}

# Ask yes/no question, default yes
# Usage: prompt_confirm "Question?" && echo yes
prompt_confirm() {
  local prompt="$1"
  local default="${2:-y}"
  if [ "$default" = "y" ]; then
    printf '%s [Y/n]: ' "$prompt"
  else
    printf '%s [y/N]: ' "$prompt"
  fi
  read -r REPLY
  REPLY="${REPLY:-$default}"
  case "$REPLY" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# Single-select from a list
# Usage: prompt_select "Prompt" option1 option2 ...
# Sets REPLY to the chosen option (string)
prompt_select() {
  local prompt="$1"; shift
  local options=("$@")
  local i

  printf '%s\n' "$prompt"
  for i in "${!options[@]}"; do
    printf '  \033[1;33m%d)\033[0m %s\n' "$((i + 1))" "${options[$i]}"
  done

  while true; do
    printf 'Choice [1-%d]: ' "${#options[@]}"
    read -r REPLY
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#options[@]}" ]; then
      REPLY="${options[$((REPLY - 1))]}"
      return 0
    fi
    printf '  Invalid choice. Try again.\n'
  done
}

# Multi-select from a list (toggle with numbers, confirm with Enter)
# Usage: prompt_multiselect "Prompt" option1 option2 ...
# Sets SELECTED_INDICES as array of 0-based indices
prompt_multiselect() {
  local prompt="$1"; shift
  local options=("$@")
  local -a selected=()
  local i

  # Initialize all as unselected
  for i in "${!options[@]}"; do
    selected[$i]=0
  done

  printf '%s\n' "$prompt"
  printf '  (Toggle with numbers, press Enter when done)\n'

  while true; do
    for i in "${!options[@]}"; do
      if [ "${selected[$i]}" -eq 1 ]; then
        printf '  \033[1;32m[x]\033[0m %d) %s\n' "$((i + 1))" "${options[$i]}"
      else
        printf '  \033[0;37m[ ]\033[0m %d) %s\n' "$((i + 1))" "${options[$i]}"
      fi
    done

    printf 'Toggle [1-%d] or Enter to confirm: ' "${#options[@]}"
    read -r REPLY

    if [ -z "$REPLY" ]; then
      break
    fi

    if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#options[@]}" ]; then
      local idx=$((REPLY - 1))
      if [ "${selected[$idx]}" -eq 1 ]; then
        selected[$idx]=0
      else
        selected[$idx]=1
      fi
    else
      printf '  Invalid choice. Try again.\n'
    fi
  done

  SELECTED_INDICES=()
  for i in "${!selected[@]}"; do
    if [ "${selected[$i]}" -eq 1 ]; then
      SELECTED_INDICES+=("$i")
    fi
  done
}

# Sanitize a string for use as Docker Compose project name
# Usage: sanitize_name "My Project"  → "my-project"
sanitize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}
