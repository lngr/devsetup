#!/usr/bin/env bats
# Tests for prompt functions from lib/prompts.sh

load test_helper

# --- prompt_header ---

@test "prompt_header: output contains title text" {
  run prompt_header "My Section"
  assert_success
  assert_output --partial "My Section"
}

@test "prompt_header: output contains decoration" {
  run prompt_header "Title"
  assert_success
  assert_output --partial "──"
}

# --- prompt_input ---

@test "prompt_input: user input is captured in REPLY" {
  prompt_input "Name" "" <<< "alice"
  assert_equal "$REPLY" "alice"
}

@test "prompt_input: empty input uses default" {
  prompt_input "Name" "bob" <<< ""
  assert_equal "$REPLY" "bob"
}

@test "prompt_input: user input overrides default" {
  prompt_input "Name" "bob" <<< "charlie"
  assert_equal "$REPLY" "charlie"
}

@test "prompt_input: prompt shows default value" {
  run prompt_input "Name" "mydefault" <<< ""
  assert_output --partial "[mydefault]"
}

@test "prompt_input: prompt without default has no brackets" {
  run prompt_input "Name" "" <<< "x"
  refute_output --partial "["
}

# --- prompt_confirm ---

@test "prompt_confirm: y returns success" {
  prompt_confirm "Continue?" <<< "y"
  assert_equal $? 0
}

@test "prompt_confirm: Y returns success" {
  prompt_confirm "Continue?" <<< "Y"
  assert_equal $? 0
}

@test "prompt_confirm: yes returns success" {
  prompt_confirm "Continue?" <<< "yes"
  assert_equal $? 0
}

@test "prompt_confirm: n returns failure" {
  run prompt_confirm "Continue?" <<< "n"
  assert_failure
}

@test "prompt_confirm: no returns failure" {
  run prompt_confirm "Continue?" <<< "no"
  assert_failure
}

@test "prompt_confirm: arbitrary text returns failure" {
  run prompt_confirm "Continue?" <<< "maybe"
  assert_failure
}

@test "prompt_confirm: empty input with default y returns success" {
  prompt_confirm "Continue?" "y" <<< ""
  assert_equal $? 0
}

@test "prompt_confirm: empty input with default n returns failure" {
  run prompt_confirm "Continue?" "n" <<< ""
  assert_failure
}

# --- prompt_select ---

@test "prompt_select: valid choice returns correct option" {
  prompt_select "Pick one" "alpha" "beta" "gamma" <<< "2"
  assert_equal "$REPLY" "beta"
}

@test "prompt_select: first option" {
  prompt_select "Pick" "a" "b" "c" <<< "1"
  assert_equal "$REPLY" "a"
}

@test "prompt_select: last option" {
  prompt_select "Pick" "a" "b" "c" <<< "3"
  assert_equal "$REPLY" "c"
}

@test "prompt_select: invalid then valid input" {
  input=$'99\n2\n'
  prompt_select "Pick" "x" "y" <<< "$input"
  assert_equal "$REPLY" "y"
}

# --- prompt_multiselect ---

@test "prompt_multiselect: enter without selection gives empty array" {
  prompt_multiselect "Pick" "a" "b" "c" <<< ""
  assert_equal "${#SELECTED_INDICES[@]}" 0
}

@test "prompt_multiselect: select one item" {
  input=$'2\n\n'
  prompt_multiselect "Pick" "a" "b" "c" <<< "$input"
  assert_equal "${#SELECTED_INDICES[@]}" 1
  assert_equal "${SELECTED_INDICES[0]}" 1
}

@test "prompt_multiselect: select multiple items" {
  input=$'1\n3\n\n'
  prompt_multiselect "Pick" "a" "b" "c" <<< "$input"
  assert_equal "${#SELECTED_INDICES[@]}" 2
  assert_equal "${SELECTED_INDICES[0]}" 0
  assert_equal "${SELECTED_INDICES[1]}" 2
}

@test "prompt_multiselect: toggle on then off gives empty" {
  input=$'2\n2\n\n'
  prompt_multiselect "Pick" "a" "b" "c" <<< "$input"
  assert_equal "${#SELECTED_INDICES[@]}" 0
}
