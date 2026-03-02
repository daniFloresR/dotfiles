#!/usr/bin/env bash
# Symlink Claude Code configuration files.

setup_claude() {
    log_info "--- Claude Code ---"
    symlink_config "config/claude/statusline.sh" "${HOME}/.claude/statusline.sh"
    symlink_config "config/claude/settings.json" "${HOME}/.claude/settings.json"
    symlink_config "config/claude/agents" "${HOME}/.claude/agents"
}
