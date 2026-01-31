#!/usr/bin/env bash
# templates.sh – Simple {{VAR}} template engine for devsetup

# Render a template file, replacing {{KEY}} with values.
# Usage: render_template <template_file> <output_file> KEY1=val1 KEY2=val2 ...
render_template() {
  local tpl="$1" out="$2"; shift 2
  local content
  content="$(cat "$tpl")"

  for pair in "$@"; do
    local key="${pair%%=*}"
    local val="${pair#*=}"
    content="${content//\{\{$key\}\}/$val}"
  done

  printf '%s\n' "$content" > "$out"
}

# Render a template to stdout (for composing fragments)
# Usage: render_template_stdout <template_file> KEY1=val1 ...
render_template_stdout() {
  local tpl="$1"; shift
  local content
  content="$(cat "$tpl")"

  for pair in "$@"; do
    local key="${pair%%=*}"
    local val="${pair#*=}"
    content="${content//\{\{$key\}\}/$val}"
  done

  printf '%s\n' "$content"
}

# Assemble service fragments into a docker-compose.services.yml
# Usage: assemble_services <output_file> <fragment1> <fragment2> ...
assemble_services() {
  local out="$1"; shift

  {
    printf 'services:\n'
    for fragment in "$@"; do
      cat "$fragment"
      printf '\n'
    done
    printf '\nnetworks:\n  devnet:\n    driver: bridge\n'
    printf '\nvolumes:\n'
    for fragment in "$@"; do
      # Extract volume names from the fragment (lines matching "  <name>_data:")
      grep -E '^\s+\S+_data:\s*$' "$fragment" 2>/dev/null || true
    done
  } > "$out"
}
