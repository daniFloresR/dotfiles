#!/bin/bash

# Config: ~/.claude/statusline.conf (all enabled by default)
#   git=true|false       show repo/branch info
#   context=true|false   show model/context bar
#   pr=true|false        show the open PR for the branch (from the .pr JSON field)
SHOW_GIT=true
SHOW_CONTEXT=true
SHOW_PR=true
CONF="$HOME/.claude/statusline.conf"
# The config file is data, not code -- read it without eval.
conf_get() {
  local v=""
  [ -f "$CONF" ] && v=$(sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([a-zA-Z]*\).*/\1/p" "$CONF" 2>/dev/null | tail -1)
  printf '%s' "${v:-$2}"
}
SHOW_GIT=$(conf_get git true)
SHOW_CONTEXT=$(conf_get context true)
SHOW_PR=$(conf_get pr true)

input=$(cat)

# Claude Code does not guarantee the directory the script runs from.
CUR_DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
[ -n "$CUR_DIR" ] && cd "$CUR_DIR" 2>/dev/null

# Nerd Font icons (raw UTF-8 bytes -- survives editors and bash 3.2)
ICON_REPO=$'\xef\x81\xbb'      # U+F07B nf-fa-folder
ICON_BRANCH=$'\xee\x82\xa0'    # U+E0A0 nf-pl-branch
ICON_PR=$'\xee\xa9\xa4'        # U+EA64 nf-cod-git_pull_request
ICON_WORKTREE=$'\xef\x84\xa6'  # U+F126 nf-fa-code_fork
ICON_ROBOT=$'\xee\xae\x99'     # U+EB99 nf-cod-robot
ICON_STATS=$'\xef\x82\x80'     # U+F080 nf-fa-bar_chart

# Real ESC bytes, so the final output can be printed with '%s' and neither %
# nor \ in the data (branch names, paths) is reinterpreted as a format spec.
E=$'\033'
GREEN="${E}[32m"
RED="${E}[31m"
CYAN="${E}[36m"
BLUE="${E}[34m"
R="${E}[0m"
DIM="${E}[90m"

# Git section
GIT_INFO=""
if [ "$SHOW_GIT" = "true" ]; then
  REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ -n "$REPO" ] && [ -n "$BRANCH" ]; then
    # Lines added/removed: branch diff vs main, fallback to all uncommitted (staged+unstaged)
    BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    BASE="${BASE#origin/}"
    if [ -z "$BASE" ]; then
      for c in main master trunk; do
        git rev-parse --verify -q "$c" >/dev/null 2>&1 && BASE="$c" && break
      done
    fi
    DIFF_RAW=""
    [ -n "$BASE" ] && DIFF_RAW=$(git diff --shortstat "$BASE"...HEAD 2>/dev/null)
    [ -z "$DIFF_RAW" ] && DIFF_RAW=$(git diff --shortstat HEAD 2>/dev/null)
    LINES_ADD=0; LINES_DEL=0; FILES_CHANGED=0
    if [ -n "$DIFF_RAW" ]; then
      LINES_ADD=$(echo "$DIFF_RAW" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
      LINES_DEL=$(echo "$DIFF_RAW" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
      FILES_CHANGED=$(echo "$DIFF_RAW" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+')
      LINES_ADD=${LINES_ADD:-0}; LINES_DEL=${LINES_DEL:-0}; FILES_CHANGED=${FILES_CHANGED:-0}
    fi
    # Include untracked files in counts (lines + file count)
    # -z with read -d '' survives filenames containing spaces; grep -I skips
    # binaries; the line count is capped so repos with thousands of untracked
    # files don't stall the render.
    UNTRACKED=0; UNTRACKED_LINES=0
    while IFS= read -r -d '' f; do
      UNTRACKED=$((UNTRACKED + 1))
      [ "$UNTRACKED" -gt 200 ] && continue
      [ -f "$f" ] || continue
      grep -Iq . "$f" 2>/dev/null || continue
      n=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
      [ -n "$(tail -c1 "$f" 2>/dev/null)" ] && n=$((${n:-0} + 1))
      UNTRACKED_LINES=$((UNTRACKED_LINES + ${n:-0}))
    done < <(git ls-files -z --others --exclude-standard 2>/dev/null)
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

    # Claude Code already resolves this: workspace.git_worktree for any git
    # worktree, worktree.name for --worktree sessions.
    WORKTREE_LINE=""
    WT_NAME=$(echo "$input" | jq -r '.workspace.git_worktree // .worktree.name // ""')
    [ -n "$WT_NAME" ] && WORKTREE_LINE="${DIM}${ICON_WORKTREE} worktree${R}  ${CYAN}${WT_NAME}${R}"

    # The branch's open PR arrives in the JSON: .pr is present only while a
    # PR (or GitLab merge request) is open and disappears once it merges or
    # closes. This used to be a backgrounded `gh pr view` with a 120s cache:
    # a network call, a dependency on authenticated gh, data up to two
    # minutes stale, and no review_state. None of it is needed.
    PR_LINE=""
    if [ "$SHOW_PR" = "true" ]; then
      PR_NUM=$(echo "$input" | jq -r '.pr.number // ""')
      PR_URL=$(echo "$input" | jq -r '.pr.url // ""')
      PR_STATE=$(echo "$input" | jq -r '.pr.review_state // ""')
      if [ -n "$PR_URL" ]; then
        PR_LINE="${DIM}${ICON_PR} pr${R}        ${BLUE}${PR_URL}${R}"
        [ -n "$PR_STATE" ] && PR_LINE="${PR_LINE}  ${DIM}${PR_STATE}${R}"
      fi
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
    C="${E}[31m"
  elif [ "$PCT" -ge 60 ]; then
    C="${E}[33m"
  else
    C="${E}[32m"
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

  # Effort arrives on stdin as .effort.level. settings.json has no
  # .effortLevel key at all, so this always rendered "default".
  # .effort is absent when the model doesn't support the parameter.
  EFFORT=$(echo "$input" | jq -r '.effort.level // ""')
  EFFORT_FMT="${EFFORT}"

  MODEL_TEXT="${MODEL}"
  USAGE_INFO="${C}${BAR} ${PCT}% ${DIM}│${C} ${TOKENS_FMT} ${DIM}│${C} ${COST_FMT} ${DIM}│${C} ${DURATION_FMT}${R}"
fi

# Emit one labeled line per section: route, branch, [worktree], model, usage
MODEL_LINE=""; USAGE_LINE=""
if [ -n "$MODEL_TEXT" ]; then
  MODEL_LINE="${DIM}${ICON_ROBOT} model${R}     ${GREEN}${MODEL_TEXT}${R}"
  # .effort is absent for models without the parameter: don't leave a dangling separator.
  [ -n "$EFFORT_FMT" ] && MODEL_LINE="${MODEL_LINE}  ${DIM}│${GREEN} ${EFFORT_FMT}${R}"
fi
[ -n "$USAGE_INFO" ] && USAGE_LINE="${DIM}${ICON_STATS} usage${R}     ${USAGE_INFO}"

NL=$'\n'
OUT=""
[ -n "$ROUTE_LINE" ]    && OUT="${OUT:+${OUT}${NL}}${ROUTE_LINE}"
[ -n "$BRANCH_LINE" ]   && OUT="${OUT:+${OUT}${NL}}${BRANCH_LINE}"
[ -n "$PR_LINE" ]       && OUT="${OUT:+${OUT}${NL}}${PR_LINE}"
[ -n "$WORKTREE_LINE" ] && OUT="${OUT:+${OUT}${NL}}${WORKTREE_LINE}"
[ -n "$MODEL_LINE" ]    && OUT="${OUT:+${OUT}${NL}}${MODEL_LINE}"
[ -n "$USAGE_LINE" ]    && OUT="${OUT:+${OUT}${NL}}${USAGE_LINE}"
# '%s' instead of the string as format: a branch like feat/100%-coverage came
# out as feat/100overage because printf ate the % as a format specifier.
[ -n "$OUT" ] && printf '%s\n' "$OUT"
