#!/usr/bin/env bash
# Install lazygit and symlink its configuration.

install_lazygit() {
    log_info "--- lazygit ---"

    if command_exists lazygit; then
        log_success "lazygit already installed"
    else
        case "$DOTFILES_OS" in
            macos)
                log_info "Installing lazygit via Homebrew..."
                brew install lazygit
                ;;
            *)
                log_info "Installing lazygit from GitHub releases..."
                local version
                version="$(github_latest_release jesseduffield lazygit)"
                version="${version#v}"  # strip leading v

                local arch_suffix
                case "$DOTFILES_ARCH" in
                    x86_64)  arch_suffix="x86_64" ;;
                    aarch64) arch_suffix="arm64" ;;
                    *)
                        log_error "Unsupported architecture: $DOTFILES_ARCH"
                        return 1
                        ;;
                esac

                local url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${arch_suffix}.tar.gz"
                local tmp_dir
                tmp_dir="$(mktemp -d)"

                log_info "Downloading lazygit v${version} for Linux ${arch_suffix}..."
                curl -fsSL "$url" | tar xz -C "$tmp_dir"
                mkdir -p "${HOME}/.local/bin"
                mv "${tmp_dir}/lazygit" "${HOME}/.local/bin/lazygit"
                chmod +x "${HOME}/.local/bin/lazygit"
                rm -rf "$tmp_dir"
                ;;
        esac
        log_success "lazygit installed"
    fi

    # Symlink config
    local target
    case "$DOTFILES_OS" in
        macos) target="${HOME}/Library/Application Support/lazygit/config.yml" ;;
        *)     target="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml" ;;
    esac
    symlink_config "config/lazygit/config.yml" "$target"
}
