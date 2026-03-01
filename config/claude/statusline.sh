#!/bin/bash

# Config: ~/.claude/statusline.conf (both enabled by default)
#   git=true|false       show repo/branch info
#   context=true|false   show model/context bar
SHOW_GIT=true
SHOW_CONTEXT=true
CONF="$HOME/.claude/statusline.conf"
if [ -f "$CONF" ]; then
  eval "$(grep -E '^(git|context)=' "$CONF")"
  SHOW_GIT="${git:-true}"
  SHOW_CONTEXT="${context:-true}"
fi

input=$(cat)

# Nerd Font icons (raw UTF-8 bytes -- survives editors and bash 3.2)
ICON_REPO=$'\xef\x81\xbb'    # U+F07B nf-fa-folder
ICON_BRANCH=$'\xee\x82\xa0'  # U+E0A0 nf-pl-branch
ICON_ROBOT=$'\xee\xae\x99'   # U+EB99 nf-cod-robot

R='\033[0m'
DIM='\033[90m'

# Git section
GIT_INFO=""
if [ "$SHOW_GIT" = "true" ]; then
  REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ -n "$REPO" ] && [ -n "$BRANCH" ]; then
    GIT_INFO="${ICON_REPO} ${REPO}  ${ICON_BRANCH} ${BRANCH}${R}"
  fi
fi

# Context section
CTX_INFO=""
if [ "$SHOW_CONTEXT" = "true" ]; then
  MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
  PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
  WINDOW=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
  TOKENS=$(echo "$input" | jq "(.context_window.used_percentage // 0) / 100 * $WINDOW | floor")

  if [ "$TOKENS" -ge 1000 ]; then
    TOKENS_FMT="$((TOKENS / 1000))k"
  else
    TOKENS_FMT="$TOKENS"
  fi

  FILLED=$((PCT * 10 / 100))
  EMPTY=$((10 - FILLED))
  BAR=""
  for ((i = 0; i < FILLED; i++)); do BAR+="█"; done
  for ((i = 0; i < EMPTY; i++)); do BAR+="░"; done

  if [ "$PCT" -ge 80 ]; then
    C='\033[31m'
  elif [ "$PCT" -ge 60 ]; then
    C='\033[33m'
  else
    C='\033[32m'
  fi

  CTX_INFO="${C}${ICON_ROBOT} ${MODEL}  ${BAR} ${PCT}%% ${DIM}│${C} ${TOKENS_FMT}${R}"
fi

# Combine with separator
if [ -n "$GIT_INFO" ] && [ -n "$CTX_INFO" ]; then
  printf "${GIT_INFO}  ${CTX_INFO}\n"
elif [ -n "$GIT_INFO" ]; then
  printf "${GIT_INFO}\n"
elif [ -n "$CTX_INFO" ]; then
  printf "${CTX_INFO}\n"
fi
