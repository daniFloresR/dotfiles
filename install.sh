#!/usr/bin/env bash
# Bootstrap a new machine with Ghostty, lazygit, and Yazi.
# Safe to re-run -- all steps are idempotent.
set -euo pipefail

# Resolve the absolute path to this repo
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
export DOTFILES_DIR

# Load shared utilities
# shellcheck source=lib/utils.sh
source "${DOTFILES_DIR}/lib/utils.sh"

detect_os
detect_arch

# Platform-specific prerequisites
case "$DOTFILES_OS" in
    macos)
        ensure_brew
        ;;
    *)
        # Ensure ~/.local/bin is on PATH for this session
        if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
            export PATH="${HOME}/.local/bin:${PATH}"
        fi
        mkdir -p "${HOME}/.local/bin"
        ;;
esac

# Interactive tool selector
ensure_gum || true
select_tools

# Install tools
# shellcheck source=lib/install_ghostty.sh
source "${DOTFILES_DIR}/lib/install_ghostty.sh"
is_selected "Ghostty" && install_ghostty

# shellcheck source=lib/install_lazygit.sh
source "${DOTFILES_DIR}/lib/install_lazygit.sh"
is_selected "lazygit" && install_lazygit

# shellcheck source=lib/install_yazi.sh
source "${DOTFILES_DIR}/lib/install_yazi.sh"
is_selected "Yazi" && install_yazi

# Claude Code config
# shellcheck source=lib/setup_claude.sh
source "${DOTFILES_DIR}/lib/setup_claude.sh"
is_selected "Claude Code" && setup_claude

# Shell integration (last, after all tools are installed)
# shellcheck source=lib/shell_integration.sh
source "${DOTFILES_DIR}/lib/shell_integration.sh"
is_selected "Shell integration" && setup_shell_integration

# Summary
echo ""
if [ -n "$_SELECTED_TOOLS" ]; then
    # Strip " -- description" suffixes for a clean summary
    local_summary="$(echo "$_SELECTED_TOOLS" | sed 's/ -- .*//' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')"
    log_success "All done! Installed: ${local_summary}"
else
    log_success "All done! (nothing selected)"
fi
log_info "Run 'source ~/.zshrc' or open a new terminal to pick up shell changes."
