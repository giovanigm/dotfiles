#!/usr/bin/env bash
input=$(cat)

# Extract fields with null defaults
FOLDER=$(echo "$input" | jq -r '.workspace.current_dir // ""' | xargs basename)
MODEL=$(echo "$input" | jq -r '.model.display_name // "..."')
USED=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
TOTAL=$SIZE

# Credits (only available on Claude.ai Pro/Max plans)
HAS_CREDITS=$(echo "$input" | jq -r '.rate_limits != null')
if [ "$HAS_CREDITS" = "true" ]; then
  CREDITS_USED=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0')
  CREDITS_LEFT=$((100 - CREDITS_USED))
fi

# Git branch (only if inside a repo)
BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH="$(git branch --show-current)"
fi

# Catppuccin Mocha palette
TEAL='\e[38;2;148;226;213m'
MAUVE='\e[38;2;203;166;247m'
SUBTEXT='\e[38;2;166;173;200m'
PEACH='\e[38;2;250;179;135m'
GREEN='\e[38;2;166;227;161m'
LAVENDER='\e[38;2;180;190;254m'
RESET='\e[0m'

# Human-readable number formatter (e.g. 20000 -> 20.0k, 1500000 -> 1.5M)
fmt() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    awk -v n="$n" 'BEGIN { printf "%.1fM", n/1000000 }'
  elif [ "$n" -ge 1000 ]; then
    awk -v n="$n" 'BEGIN { printf "%.1fk", n/1000 }'
  else
    echo "$n"
  fi
}

USED_FMT=$(fmt "$USED")
TOTAL_FMT=$(fmt "$TOTAL")

# Build branch segment
if [ -n "$BRANCH" ]; then
  BRANCH_SEGMENT="${SUBTEXT} (${BRANCH})${RESET}"
else
  BRANCH_SEGMENT=""
fi

# Build credits segment (only if rate limits are available)
if [ "$HAS_CREDITS" = "true" ]; then
  CREDITS_SEGMENT=" ${SUBTEXT}│${RESET} ${LAVENDER}${CREDITS_LEFT}%${RESET}${SUBTEXT} credits${RESET}"
else
  CREDITS_SEGMENT=""
fi

echo -e "${TEAL}${FOLDER}${BRANCH_SEGMENT}  ${MAUVE}${MODEL}${RESET} ${SUBTEXT}│${RESET} ${PEACH}${USED_FMT}${RESET}${SUBTEXT}/${RESET}${GREEN}${TOTAL_FMT}${RESET}${CREDITS_SEGMENT}"
