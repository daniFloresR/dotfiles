#!/usr/bin/env bash
# Append shell integration blocks to ~/.zshrc (idempotent).

setup_shell_integration() {
    log_info "--- Shell integration ---"

    append_block_if_missing "lazygit" 'alias lg="lazygit"'

    append_block_if_missing "yazi" 'function y() {
	local tmp
	tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd" || return
	fi
	rm -f -- "$tmp"
}'

    append_block_if_missing "zoxide" 'eval "$(zoxide init zsh)"'
}
