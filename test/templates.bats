#!/usr/bin/env bats
# Tests for lib/templates.sh

load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# --- render_template_stdout ---

@test "render_template_stdout: simple substitution" {
  printf 'Hello {{NAME}}!\n' > "$TEST_TMP/tpl"
  run render_template_stdout "$TEST_TMP/tpl" "NAME=World"
  assert_success
  assert_output "Hello World!"
}

@test "render_template_stdout: multiple variables" {
  printf '{{A}} and {{B}}\n' > "$TEST_TMP/tpl"
  run render_template_stdout "$TEST_TMP/tpl" "A=foo" "B=bar"
  assert_success
  assert_output "foo and bar"
}

@test "render_template_stdout: same key appears twice" {
  printf '{{X}}/{{X}}\n' > "$TEST_TMP/tpl"
  run render_template_stdout "$TEST_TMP/tpl" "X=val"
  assert_success
  assert_output "val/val"
}

@test "render_template_stdout: no placeholders unchanged" {
  printf 'static text\n' > "$TEST_TMP/tpl"
  run render_template_stdout "$TEST_TMP/tpl"
  assert_success
  assert_output "static text"
}

@test "render_template_stdout: unreplaced placeholder stays" {
  printf '{{MISSING}} here\n' > "$TEST_TMP/tpl"
  run render_template_stdout "$TEST_TMP/tpl"
  assert_success
  assert_output "{{MISSING}} here"
}

@test "render_template_stdout: value with spaces" {
  printf 'Hi {{NAME}}\n' > "$TEST_TMP/tpl"
  run render_template_stdout "$TEST_TMP/tpl" "NAME=John Doe"
  assert_success
  assert_output "Hi John Doe"
}

@test "render_template_stdout: empty value" {
  printf 'before{{X}}after\n' > "$TEST_TMP/tpl"
  run render_template_stdout "$TEST_TMP/tpl" "X="
  assert_success
  assert_output "beforeafter"
}

@test "render_template_stdout: multiline template" {
  printf 'line1 {{A}}\nline2 {{B}}\n' > "$TEST_TMP/tpl"
  run render_template_stdout "$TEST_TMP/tpl" "A=x" "B=y"
  assert_success
  assert_line --index 0 "line1 x"
  assert_line --index 1 "line2 y"
}

# --- render_template ---

@test "render_template: creates output file" {
  printf 'Hello {{NAME}}\n' > "$TEST_TMP/tpl"
  render_template "$TEST_TMP/tpl" "$TEST_TMP/out" "NAME=World"
  [ -f "$TEST_TMP/out" ]
}

@test "render_template: output content is correct" {
  printf '{{A}} - {{B}}\n' > "$TEST_TMP/tpl"
  render_template "$TEST_TMP/tpl" "$TEST_TMP/out" "A=hello" "B=world"
  run cat "$TEST_TMP/out"
  assert_output "hello - world"
}

# --- assemble_services ---

@test "assemble_services: single fragment" {
  cat > "$TEST_TMP/frag1" <<'EOF'
  myapp:
    image: myapp:latest
    networks:
      - devnet
EOF
  assemble_services "$TEST_TMP/out" "$TEST_TMP/frag1"
  run cat "$TEST_TMP/out"
  assert_output --partial "services:"
  assert_output --partial "myapp:"
  assert_output --partial "networks:"
  assert_output --partial "devnet:"
}

@test "assemble_services: multiple fragments" {
  cat > "$TEST_TMP/frag1" <<'EOF'
  app1:
    image: app1:latest
EOF
  cat > "$TEST_TMP/frag2" <<'EOF'
  app2:
    image: app2:latest
EOF
  assemble_services "$TEST_TMP/out" "$TEST_TMP/frag1" "$TEST_TMP/frag2"
  run cat "$TEST_TMP/out"
  assert_output --partial "app1:"
  assert_output --partial "app2:"
}

@test "assemble_services: extracts volume names" {
  cat > "$TEST_TMP/frag1" <<'EOF'
  postgres:
    image: postgres:16
    volumes:
      - postgres_data:/var/lib/postgresql/data
EOF
  # The volume declaration for the top-level volumes section
  cat > "$TEST_TMP/frag_vol" <<EOF
  postgres:
    image: postgres:16
  postgres_data:
EOF
  assemble_services "$TEST_TMP/out" "$TEST_TMP/frag_vol"
  run cat "$TEST_TMP/out"
  assert_output --partial "volumes:"
  assert_output --partial "postgres_data:"
}

@test "assemble_services: output contains bridge network" {
  cat > "$TEST_TMP/frag1" <<'EOF'
  svc:
    image: svc:latest
EOF
  assemble_services "$TEST_TMP/out" "$TEST_TMP/frag1"
  run cat "$TEST_TMP/out"
  assert_output --partial "driver: bridge"
}
