#!/usr/bin/env bash
# Ghost integration test suite
set -euo pipefail

GHOST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
export PATH="${GHOST_ROOT}/bin:$PATH"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31m✗\033[0m %s\n" "$1"; }
assert() {
  if eval "$1" 2>/dev/null; then
    pass "$2"
  else
    fail "$2"
  fi
}

section() { printf "\n\033[1m%s\033[0m\n" "$1"; }

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

# Configure git identity for test commits
export GIT_AUTHOR_NAME="Ghost Test"
export GIT_AUTHOR_EMAIL="ghost@test.local"
export GIT_COMMITTER_NAME="Ghost Test"
export GIT_COMMITTER_EMAIL="ghost@test.local"

section "Test 1: ghost init"
cd "$TEST_DIR"
git init -q
ghost init

assert '[ -x .git/hooks/prepare-commit-msg ]' "hook installed and executable"
assert '[ -d .ghost ]' ".ghost directory created"

section "Test 2: ghost commit generates code"
ghost commit -m "Create a C program called hello.c that prints 'Hello, Ghost!' to stdout and exits 0"

assert '[ -f hello.c ]' "hello.c was created"
assert 'git log --oneline -1 | grep -q "Create a C program"' "commit message contains prompt"
assert 'git log -1 --format=%B | grep -q "ghost-meta"' "commit has ghost metadata"
assert 'git log -1 --format=%B | grep -q "ghost-prompt:"' "commit has ghost-prompt field"
assert 'git log -1 --format=%B | grep -q "ghost-model:"' "commit has ghost-model field"
assert 'git log -1 --format=%B | grep -q "ghost-session:"' "commit has ghost-session field"
assert 'git log -1 --format=%B | grep -q "ghost-files:"' "commit has ghost-files field"

section "Test 3: generated C code compiles"
cc -o hello hello.c
assert '[ -x hello ]' "hello.c compiled successfully"

section "Test 4: compiled program runs correctly"
OUTPUT="$(./hello)"
assert '[ "$OUTPUT" = "Hello, Ghost!" ]' "program outputs 'Hello, Ghost!'"

section "Test 5: ghost log shows the commit"
GHOST_LOG="$(ghost log)"
assert 'echo "$GHOST_LOG" | grep -q "Create a C program"' "ghost log shows prompt"

section "Test 6: ghost commit --dry-run does not commit"
BEFORE="$(git rev-parse HEAD)"
ghost commit --dry-run -m "add a Makefile" || true
AFTER="$(git rev-parse HEAD)"
assert '[ "$BEFORE" = "$AFTER" ]' "dry-run did not create a commit"

section "Test 7: GHOST_SKIP passthrough"
echo "// manual" > manual.c
git add manual.c
GHOST_SKIP=1 ghost commit -m "manual commit"
assert '! git log -1 --format=%B | grep -q "ghost-meta"' "GHOST_SKIP skips ghost metadata"

# --- Summary ---
printf "\n\033[1mResults:\033[0m %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
