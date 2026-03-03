#!/usr/bin/env bash
# ghost-common.sh — shared constants and utilities

GHOST_META_MARKER="ghost-meta"
GHOST_PROMPT_KEY="ghost-prompt"
GHOST_AGENT_KEY="ghost-agent"
GHOST_MODEL_KEY="ghost-model"
GHOST_SESSION_KEY="ghost-session"
GHOST_FILES_KEY="ghost-files"

GHOST_DEFAULT_AGENT="${GHOST_AGENT:-claude}"
GHOST_DEFAULT_MODEL="${GHOST_MODEL:-claude-sonnet-4-6}"

ghost_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

ghost_ensure_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: not a git repository. Run 'ghost init' first." >&2
    exit 1
  fi
}

ghost_is_skip() {
  [ "${GHOST_SKIP:-0}" = "1" ]
}

ghost_hooks_path() {
  local hooks_path
  hooks_path="$(git config --local core.hooksPath 2>/dev/null)"
  if [ -z "$hooks_path" ]; then
    hooks_path="$(git rev-parse --git-dir)/hooks"
  else
    # Make absolute if relative
    if [[ "$hooks_path" != /* ]]; then
      hooks_path="$(git rev-parse --show-toplevel)/$hooks_path"
    fi
  fi
  echo "$hooks_path"
}

# ── Terminal / colour helpers ───────────────────────────────────────────────

ghost_is_tty() { [ -t 1 ] && [ -t 2 ]; }

# Call once at the start of any command that wants colour.
ghost_init_colors() {
  if ghost_is_tty; then
    GH_PINK=$'\033[38;5;213m'    # hot pink
    GH_MPINK=$'\033[38;5;219m'   # soft pink
    GH_PURPLE=$'\033[38;5;141m'  # medium orchid
    GH_DPURPLE=$'\033[38;5;105m' # deep purple
    GH_BLUE=$'\033[38;5;75m'     # cornflower blue
    GH_CYAN=$'\033[38;5;87m'     # bright cyan
    GH_RED=$'\033[91m'
    GH_GREEN=$'\033[38;5;120m'
    GH_DIM=$'\033[2m'
    GH_BOLD=$'\033[1m'
    GH_RESET=$'\033[0m'
  else
    GH_PINK='' GH_MPINK='' GH_PURPLE='' GH_DPURPLE=''
    GH_BLUE='' GH_CYAN='' GH_RED='' GH_GREEN=''
    GH_DIM='' GH_BOLD='' GH_RESET=''
  fi
}

gh_info()    { printf "%b%s%b\n"        "${GH_BLUE}"   "$*" "${GH_RESET}"; }
gh_label()   { printf "%b%s%b\n"        "${GH_PURPLE}" "$*" "${GH_RESET}"; }
gh_success() { printf "%b%s%b\n"        "${GH_PINK}"   "$*" "${GH_RESET}"; }
gh_error()   { printf "%b%s%b\n"        "${GH_RED}"    "$*" "${GH_RESET}" >&2; }
gh_dim()     { printf "%b%s%b\n"        "${GH_DIM}"    "$*" "${GH_RESET}"; }
# gh_kv key value — prints "  key   value" with purple key, blue value
gh_kv() {
  printf "  %b%-9s%b %b%s%b\n" \
    "${GH_PURPLE}" "$1" "${GH_RESET}" \
    "${GH_BLUE}"   "$2" "${GH_RESET}"
}

# ── Spinner ─────────────────────────────────────────────────────────────────

_GHOST_SPINNER_PID=""

ghost_spinner_start() {
  local msg="${1:-working…}"
  if ! [ -t 2 ]; then
    printf "%s\n" "$msg" >&2
    return 0
  fi

  # braille spinner frames
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  # colours cycle pink → purple → blue → purple → pink
  local -a colors=(
    $'\033[38;5;213m' $'\033[38;5;212m' $'\033[38;5;177m'
    $'\033[38;5;141m' $'\033[38;5;105m' $'\033[38;5;75m'
    $'\033[38;5;75m'  $'\033[38;5;105m' $'\033[38;5;141m'
    $'\033[38;5;177m'
  )
  local lc=$'\033[38;5;141m'  # label colour (purple)
  local rs=$'\033[0m'

  printf '\033[?25l' >&2  # hide cursor

  (
    trap 'exit 0' TERM
    trap '' INT HUP
    local i=0
    local nf=${#frames[@]} nc=${#colors[@]}
    while true; do
      local f="${frames[$((i % nf))]}"
      local c="${colors[$((i % nc))]}"
      printf "\r%b%s%b %b%s%b" "$c" "$f" "$rs" "$lc" "$msg" "$rs" >&2
      sleep 0.08
      i=$(( i + 1 ))
    done
  ) &
  _GHOST_SPINNER_PID=$!
}

ghost_spinner_stop() {
  if [ -n "${_GHOST_SPINNER_PID:-}" ]; then
    kill "$_GHOST_SPINNER_PID" 2>/dev/null || true
    wait "$_GHOST_SPINNER_PID" 2>/dev/null || true
    _GHOST_SPINNER_PID=""
  fi
  if [ -t 2 ]; then
    printf '\r\033[2K' >&2  # erase spinner line
    printf '\033[?25h' >&2  # restore cursor
  fi
}
