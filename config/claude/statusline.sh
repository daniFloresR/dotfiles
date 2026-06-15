#!/bin/bash

# Config: ~/.claude/statusline.conf (all enabled by default)
#   git=true|false       show repo/branch info
#   context=true|false   show model/context bar
#   pr=true|false        show the open PR url for the branch (uses gh, cached)
SHOW_GIT=true
SHOW_CONTEXT=true
SHOW_PR=true
CONF="$HOME/.claude/statusline.conf"
if [ -f "$CONF" ]; then
  eval "$(grep -E '^(git|context|pr)=' "$CONF")"
  SHOW_GIT="${git:-true}"
  SHOW_CONTEXT="${context:-true}"
  SHOW_PR="${pr:-true}"
fi

input=$(cat)

# Nerd Font icons (raw UTF-8 bytes -- survives editors and bash 3.2)
ICON_REPO=$'\xef\x81\xbb'      # U+F07B nf-fa-folder
ICON_BRANCH=$'\xee\x82\xa0'    # U+E0A0 nf-pl-branch
ICON_PR=$'\xee\xa9\xa4'        # U+EA64 nf-cod-git_pull_request
ICON_WORKTREE=$'\xef\x84\xa6'  # U+F126 nf-fa-code_fork
ICON_ROBOT=$'\xee\xae\x99'     # U+EB99 nf-cod-robot
ICON_STATS=$'\xef\x82\x80'     # U+F080 nf-fa-bar_chart

GREEN='\033[32m'
RED='\033[31m'
CYAN='\033[36m'
BLUE='\033[34m'
R='\033[0m'
DIM='\033[90m'

# Git section
GIT_INFO=""
if [ "$SHOW_GIT" = "true" ]; then
  REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ -n "$REPO" ] && [ -n "$BRANCH" ]; then
    # Lines added/removed: branch diff vs main, fallback to all uncommitted (staged+unstaged)
    DIFF_RAW=$(git diff --shortstat main...HEAD 2>/dev/null)
    [ -z "$DIFF_RAW" ] && DIFF_RAW=$(git diff --shortstat HEAD 2>/dev/null)
    LINES_ADD=0; LINES_DEL=0; FILES_CHANGED=0
    if [ -n "$DIFF_RAW" ]; then
      LINES_ADD=$(echo "$DIFF_RAW" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
      LINES_DEL=$(echo "$DIFF_RAW" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
      FILES_CHANGED=$(echo "$DIFF_RAW" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+')
      LINES_ADD=${LINES_ADD:-0}; LINES_DEL=${LINES_DEL:-0}; FILES_CHANGED=${FILES_CHANGED:-0}
    fi
    # Include untracked files in counts (lines + file count)
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null)
    UNTRACKED=0; UNTRACKED_LINES=0
    if [ -n "$UNTRACKED_FILES" ]; then
      UNTRACKED=$(echo "$UNTRACKED_FILES" | wc -l | tr -d ' ')
      UNTRACKED_LINES=$(echo "$UNTRACKED_FILES" | xargs cat 2>/dev/null | wc -l | tr -d ' ')
      UNTRACKED_LINES=${UNTRACKED_LINES:-0}
    fi
    FILES_CHANGED=$((FILES_CHANGED + UNTRACKED))
    LINES_ADD=$((LINES_ADD + UNTRACKED_LINES))
    DIFF_STAT=""
    if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ] || [ "$FILES_CHANGED" -gt 0 ]; then
      if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
        DIFF_STAT="  ${GREEN}+${LINES_ADD}${R} ${RED}-${LINES_DEL}${R} ${DIM}(${FILES_CHANGED}f)${R}"
      else
        DIFF_STAT="  ${DIM}(${FILES_CHANGED}f)${R}"
      fi
    fi
    REL_PATH=$(git rev-parse --show-toplevel 2>/dev/null | sed "s|^$HOME/||")

    # Detect linked worktree: its git-dir lives under <main>/.git/worktrees/<name>.
    # Rendered as its own line, only when inside a worktree.
    WORKTREE_LINE=""
    GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null)
    case "$GIT_DIR" in
      */worktrees/*)
        WT_NAME=$(basename "$GIT_DIR")
        WORKTREE_LINE="${DIM}${ICON_WORKTREE} worktree${R}  ${CYAN}${WT_NAME}${R}"
        ;;
    esac

    # Open PR for this branch. Network calls (gh) are expensive, so we cache the
    # result per repo+branch and refresh in the background: the render reads the
    # cached value instantly and never blocks on the network (stale-while-revalidate).
    PR_LINE=""
    if [ "$SHOW_PR" = "true" ] && command -v gh >/dev/null 2>&1; then
      PR_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
      PR_CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline"
      mkdir -p "$PR_CACHE_DIR" 2>/dev/null
      PR_KEY=$(printf '%s' "${PR_TOPLEVEL}:${BRANCH}" | tr -c 'a-zA-Z0-9' '_' | cut -c1-200)
      PR_CACHE="$PR_CACHE_DIR/pr-${PR_KEY}"
      PR_TTL=120

      PR_NUM=""; PR_URL=""
      [ -f "$PR_CACHE" ] && IFS=$'\t' read -r PR_NUM PR_URL < "$PR_CACHE"

      PR_AGE=999999
      if [ -f "$PR_CACHE" ]; then
        PR_MTIME=$(stat -f %m "$PR_CACHE" 2>/dev/null || stat -c %Y "$PR_CACHE" 2>/dev/null || echo 0)
        PR_AGE=$(( $(date +%s) - PR_MTIME ))
      fi
      if [ "$PR_AGE" -ge "$PR_TTL" ]; then
        touch "$PR_CACHE" 2>/dev/null  # claim now so rapid re-renders don't stampede gh
        (
          OUT=$(gh pr view --json number,url --jq '"\(.number)\t\(.url)"' 2>/dev/null)
          printf '%s\n' "$OUT" > "${PR_CACHE}.$$" && mv "${PR_CACHE}.$$" "$PR_CACHE"
        ) >/dev/null 2>&1 &
      fi

      [ -n "$PR_URL" ] && PR_LINE="${DIM}${ICON_PR} pr${R}        ${BLUE}${PR_URL}${R}"
    fi

    ROUTE_LINE="${DIM}${ICON_REPO} route${R}     ${REL_PATH}"
    BRANCH_LINE="${DIM}${ICON_BRANCH} branch${R}    ${BRANCH}${DIFF_STAT}${R}"
  fi
fi

# Context section
CTX_INFO=""
if [ "$SHOW_CONTEXT" = "true" ]; then
  MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
  WINDOW=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

  # Calculate percentage from current_usage (survives compaction)
  # Falls back to used_percentage if current_usage is null
  PCT=$(echo "$input" | jq -r '
    if .context_window.current_usage then
      ((.context_window.current_usage.input_tokens // 0)
       + (.context_window.current_usage.cache_creation_input_tokens // 0)
       + (.context_window.current_usage.cache_read_input_tokens // 0))
      / (.context_window.context_window_size // 200000) * 100 | floor
    else
      .context_window.used_percentage // 0 | floor
    end
  ')
  TOKENS=$(echo "$input" | jq -r '
    if .context_window.current_usage then
      (.context_window.current_usage.input_tokens // 0)
      + (.context_window.current_usage.cache_creation_input_tokens // 0)
      + (.context_window.current_usage.cache_read_input_tokens // 0)
    else
      (.context_window.used_percentage // 0) / 100
      * (.context_window.context_window_size // 200000) | floor
    end
  ')

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

  COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
  COST_FMT=$(printf '$%.2f' "$COST")

  DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
  DURATION_S=$((DURATION_MS / 1000))
  DURATION_H=$((DURATION_S / 3600))
  DURATION_M=$(((DURATION_S % 3600) / 60))
  if [ "$DURATION_H" -gt 0 ]; then
    DURATION_FMT="${DURATION_H}h${DURATION_M}m"
  else
    DURATION_FMT="${DURATION_M}m"
  fi

  EFFORT=$(jq -r '.effortLevel // "default"' "$HOME/.claude/settings.json" 2>/dev/null)
  EFFORT_FMT="${EFFORT}"

  MODEL_TEXT="${MODEL}"
  USAGE_INFO="${C}${BAR} ${PCT}%% ${DIM}│${C} ${TOKENS_FMT} ${DIM}│${C} ${COST_FMT} ${DIM}│${C} ${DURATION_FMT}${R}"
fi

# Emit one labeled line per section: route, branch, [worktree], model, usage
MODEL_LINE=""; USAGE_LINE=""
[ -n "$MODEL_TEXT" ] && MODEL_LINE="${DIM}${ICON_ROBOT} model${R}     ${GREEN}${MODEL_TEXT}  ${DIM}│${GREEN} ${EFFORT_FMT}${R}"
[ -n "$USAGE_INFO" ] && USAGE_LINE="${DIM}${ICON_STATS} usage${R}     ${USAGE_INFO}"

OUT=""
[ -n "$ROUTE_LINE" ]    && OUT="${OUT:+${OUT}\n}${ROUTE_LINE}"
[ -n "$BRANCH_LINE" ]   && OUT="${OUT:+${OUT}\n}${BRANCH_LINE}"
[ -n "$PR_LINE" ]       && OUT="${OUT:+${OUT}\n}${PR_LINE}"
[ -n "$WORKTREE_LINE" ] && OUT="${OUT:+${OUT}\n}${WORKTREE_LINE}"
[ -n "$MODEL_LINE" ]    && OUT="${OUT:+${OUT}\n}${MODEL_LINE}"
[ -n "$USAGE_LINE" ]    && OUT="${OUT:+${OUT}\n}${USAGE_LINE}"
[ -n "$OUT" ] && printf "${OUT}\n"
