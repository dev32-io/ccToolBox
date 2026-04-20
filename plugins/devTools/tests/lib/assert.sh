#!/usr/bin/env bash
# Minimal bash test assertions. Use with `set -euo pipefail`.

_pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
_fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=$((FAILED+1)); }

: "${FAILED:=0}"
: "${TESTS:=0}"

assert_eq() {
  TESTS=$((TESTS+1))
  local expected="$1" actual="$2" msg="${3:-assert_eq}"
  if [[ "$expected" == "$actual" ]]; then
    _pass "$msg"
  else
    _fail "$msg"
    printf '    expected: %q\n' "$expected"
    printf '    actual:   %q\n' "$actual"
  fi
}

assert_contains() {
  TESTS=$((TESTS+1))
  local haystack="$1" needle="$2" msg="${3:-assert_contains}"
  if [[ "$haystack" == *"$needle"* ]]; then
    _pass "$msg"
  else
    _fail "$msg"
    printf '    needle:   %q\n' "$needle"
    printf '    haystack: %q\n' "$haystack"
  fi
}

assert_not_contains() {
  TESTS=$((TESTS+1))
  local haystack="$1" needle="$2" msg="${3:-assert_not_contains}"
  if [[ "$haystack" != *"$needle"* ]]; then
    _pass "$msg"
  else
    _fail "$msg"
    printf '    needle:   %q\n' "$needle"
    printf '    haystack: %q\n' "$haystack"
  fi
}

assert_exit_code() {
  TESTS=$((TESTS+1))
  local expected="$1" actual="$2" msg="${3:-assert_exit_code}"
  if [[ "$expected" == "$actual" ]]; then
    _pass "$msg"
  else
    _fail "$msg (expected $expected, got $actual)"
  fi
}

summary() {
  printf '\n%d tests, %d failed\n' "$TESTS" "$FAILED"
  [[ "$FAILED" == 0 ]]
}
