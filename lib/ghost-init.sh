#!/usr/bin/env bash
# ghost-init.sh — initialize a repo for ghost

set -euo pipefail

# shellcheck source=lib/ghost-common.sh
source "${GHOST_ROOT}/lib/ghost-common.sh"

HOOK_CONTENT='#!/usr/bin/env bash
# Ghost prepare-commit-msg hook
# Installed by ghost init — do not remove this line
# $1 = commit message file, $2 = source (message|template|merge|squash|commit)
# Ghost only enriches manual ghost commits; skip all other cases
[ "${2:-}" = "message" ] || exit 0
[ "${GHOST_ENRICHING:-0}" = "1" ] || exit 0
exit 0
'

cmd_init() {
  local force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=1; shift ;;
      *) echo "error: unknown option: $1" >&2; exit 1 ;;
    esac
  done

  # Init git repo if needed
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Initializing git repository..."
    git init
  fi

  # Create .ghost directory
  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  mkdir -p "${repo_root}/.ghost"
  echo "Created ${repo_root}/.ghost/"

  # Install prepare-commit-msg hook
  local hooks_dir
  hooks_dir="$(ghost_hooks_path)"
  mkdir -p "$hooks_dir"

  local hook_file="${hooks_dir}/prepare-commit-msg"

  if [ -f "$hook_file" ]; then
    if grep -q "Ghost prepare-commit-msg hook" "$hook_file" 2>/dev/null; then
      echo "Hook already installed at ${hook_file}"
    else
      local backup="${hook_file}.pre-ghost"
      echo "Backing up existing hook to ${backup}"
      cp "$hook_file" "$backup"
      echo "$HOOK_CONTENT" > "$hook_file"
      chmod +x "$hook_file"
      echo "Installed prepare-commit-msg hook at ${hook_file}"
    fi
  else
    printf '%s' "$HOOK_CONTENT" > "$hook_file"
    chmod +x "$hook_file"
    echo "Installed prepare-commit-msg hook at ${hook_file}"
  fi

  echo ""
  echo "Ghost initialized. Try: ghost commit -m \"your intent here\""
}
