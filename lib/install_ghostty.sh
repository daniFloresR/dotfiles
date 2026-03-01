#!/usr/bin/env bash
# Install Ghostty and symlink its configuration.

install_ghostty() {
    log_info "--- Ghostty ---"

    if command_exists ghostty; then
        log_success "Ghostty already installed"
    else
        case "$DOTFILES_OS" in
            macos)
                log_info "Installing Ghostty via Homebrew..."
                brew install --cask ghostty
                ;;
            ubuntu)
                log_info "Installing Ghostty from ghostty-org PPA..."
                if command_exists apt-get; then
                    sudo apt-get update -qq
                    sudo apt-get install -y software-properties-common
                    sudo add-apt-repository -y ppa:ghostty-org/ppa
                    sudo apt-get update -qq
                    sudo apt-get install -y ghostty
                else
                    log_error "apt-get not found. Install Ghostty manually: https://ghostty.org/download"
                    return 1
                fi
                ;;
            fedora)
                log_info "Installing Ghostty via COPR..."
                sudo dnf copr enable -y pgdev/ghostty
                sudo dnf install -y ghostty
                ;;
            arch)
                log_info "Installing Ghostty via pacman..."
                sudo pacman -S --noconfirm ghostty
                ;;
            *)
                log_warn "Unsupported OS for automatic Ghostty install."
                log_warn "Install manually: https://ghostty.org/download"
                ;;
        esac
    fi

    # Symlink config
    local target
    case "$DOTFILES_OS" in
        macos) target="${HOME}/Library/Application Support/com.mitchellh.ghostty/config" ;;
        *)     target="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" ;;
    esac
    symlink_config "config/ghostty/config" "$target"
}
