#!/usr/bin/env bats
# Tests for sanitize_name() from lib/prompts.sh

load test_helper

@test "sanitize_name: lowercase passthrough" {
  result="$(sanitize_name "myproject")"
  assert_equal "$result" "myproject"
}

@test "sanitize_name: uppercase to lowercase" {
  result="$(sanitize_name "MyProject")"
  assert_equal "$result" "myproject"
}

@test "sanitize_name: spaces to hyphens" {
  result="$(sanitize_name "my project")"
  assert_equal "$result" "my-project"
}

@test "sanitize_name: special characters replaced" {
  result="$(sanitize_name "my_project@v2")"
  assert_equal "$result" "my-project-v2"
}

@test "sanitize_name: multiple hyphens collapsed" {
  result="$(sanitize_name "my---project")"
  assert_equal "$result" "my-project"
}

@test "sanitize_name: leading hyphen removed" {
  result="$(sanitize_name "-myproject")"
  assert_equal "$result" "myproject"
}

@test "sanitize_name: trailing hyphen removed" {
  result="$(sanitize_name "myproject-")"
  assert_equal "$result" "myproject"
}

@test "sanitize_name: dots replaced" {
  result="$(sanitize_name "my.project.name")"
  assert_equal "$result" "my-project-name"
}

@test "sanitize_name: digits preserved" {
  result="$(sanitize_name "project123")"
  assert_equal "$result" "project123"
}

@test "sanitize_name: empty string" {
  result="$(sanitize_name "")"
  assert_equal "$result" ""
}

@test "sanitize_name: only special characters" {
  result="$(sanitize_name "@#\$%")"
  assert_equal "$result" ""
}

@test "sanitize_name: combined edge cases" {
  result="$(sanitize_name " --My Project!! ")"
  assert_equal "$result" "my-project"
}
