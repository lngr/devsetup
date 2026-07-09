#!/usr/bin/env bats
# Tests für das Sourcen von /etc/profile unter set -u.
#
# Snippets unter /etc/profile.d (z.B. apps-bin-path.sh aus dem snapd-Paket)
# expandieren Variablen wie XDG_DATA_DIRS, die unset sein können. Unter
# nounset bricht eine solche Expansion die gesamte Shell ab; ein "|| true"
# am Source-Befehl fängt das nicht ab. Deshalb muss jede Stelle, die
# /etc/profile sourcet, nounset davor aussetzen und danach wieder aktivieren.

load test_helper

# Alle Dateien des Repos, die /etc/profile sourcen.
PROFILE_SOURCING_FILES=(
  "templates/postCreateCommand.sh.tpl"
  "templates/postStartCommand.sh.tpl"
  "scripts/install-agents.sh"
  "scripts/update-agents.sh"
  "exec-devcontainer.sh"
)

# Prüft, dass in der Datei jedem ". /etc/profile" ein "set +u" vorausgeht
# und ein "set -u" folgt.
assert_profile_sourced_without_nounset() {
  local file="$1"
  local occurrences
  occurrences="$(grep -c '^  \. /etc/profile' "$file")"
  (( occurrences >= 1 )) || {
    echo "keine /etc/profile-Source-Stelle in $file gefunden" >&2
    return 1
  }
  run bash -c "grep -B1 '^  \. /etc/profile' '$file' | grep -c 'set +u'"
  assert_success
  assert_output "$occurrences"
  run bash -c "grep -A1 '^  \. /etc/profile' '$file' | grep -c 'set -u'"
  assert_success
  assert_output "$occurrences"
}

@test "alle /etc/profile-Source-Stellen setzen nounset aus" {
  for f in "${PROFILE_SOURCING_FILES[@]}"; do
    assert_profile_sourced_without_nounset "$REPO_ROOT/$f"
  done
}

@test "exec-devcontainer.sh generiert beide Overlay-Hooks mit nounset-Guard" {
  run bash -c "grep -c '^  \. /etc/profile' '$REPO_ROOT/exec-devcontainer.sh'"
  assert_success
  assert_output "2"
}

@test "nounset-Guard überlebt ein Profile-Snippet mit unset-Variable" {
  local tmp
  tmp="$(mktemp -d)"
  cat >"$tmp/fake-profile" <<'EOF'
if test -z "$SOME_UNSET_VARIABLE_XYZ" ; then
  export SOME_UNSET_VARIABLE_XYZ="/usr/local/share"
fi
EOF
  run bash -c "set -euo pipefail
if [ -f '$tmp/fake-profile' ]; then
  set +u
  . '$tmp/fake-profile' || true
  set -u
fi
echo survived"
  rm -rf "$tmp"
  assert_success
  assert_output --partial "survived"
}
