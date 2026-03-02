#!/usr/bin/env bash
# Install Yazi and its optional dependencies, then symlink configuration.

install_yazi() {
    log_info "--- Yazi ---"

    if command_exists yazi; then
        log_success "Yazi already installed"
    else
        case "$DOTFILES_OS" in
            macos)
                log_info "Installing Yazi and dependencies via Homebrew..."
                brew install yazi fd ripgrep fzf zoxide sevenzip resvg imagemagick font-symbols-only-nerd-font
                ;;
            *)
                _install_yazi_linux
                ;;
        esac
        log_success "Yazi installed"
    fi

    # Symlink config directory contents
    symlink_config "config/yazi/yazi.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/yazi/yazi.toml"
}

_install_yazi_linux() {
    # Install yazi binary from GitHub releases
    local version
    version="$(github_latest_release sxyazi yazi)"

    local arch_suffix
    case "$DOTFILES_ARCH" in
        x86_64)  arch_suffix="x86_64" ;;
        aarch64) arch_suffix="aarch64" ;;
        *)
            log_error "Unsupported architecture: $DOTFILES_ARCH"
            return 1
            ;;
    esac

    local url="https://github.com/sxyazi/yazi/releases/download/${version}/yazi-${arch_suffix}-unknown-linux-gnu.zip"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    log_info "Downloading Yazi ${version} for Linux ${arch_suffix}..."
    curl -fsSL -o "${tmp_dir}/yazi.zip" "$url"
    unzip -q "${tmp_dir}/yazi.zip" -d "$tmp_dir"
    mkdir -p "${HOME}/.local/bin"
    mv "${tmp_dir}"/yazi-*/yazi "${HOME}/.local/bin/yazi"
    mv "${tmp_dir}"/yazi-*/ya "${HOME}/.local/bin/ya"
    chmod +x "${HOME}/.local/bin/yazi" "${HOME}/.local/bin/ya"
    rm -rf "$tmp_dir"

    # Install deps via distro package manager
    _install_yazi_linux_deps

    # Install nerd font
    _install_nerd_font_linux
}

_install_yazi_linux_deps() {
    case "$DOTFILES_OS" in
        ubuntu)
            log_info "Installing Yazi dependencies via apt..."
            apt_update
            sudo apt-get install -y fd-find ripgrep fzf zoxide p7zip-full imagemagick
            ;;
        fedora)
            log_info "Installing Yazi dependencies via dnf..."
            sudo dnf install -y fd-find ripgrep fzf zoxide p7zip ImageMagick
            ;;
        arch)
            log_info "Installing Yazi dependencies via pacman..."
            sudo pacman -S --noconfirm fd ripgrep fzf zoxide p7zip imagemagick
            ;;
        *)
            log_warn "Cannot auto-install Yazi deps on this OS. Install manually: fd, ripgrep, fzf, zoxide, 7z, imagemagick"
            ;;
    esac

    # resvg: not in most distro repos, install from GitHub releases
    if ! command_exists resvg; then
        log_info "Installing resvg from GitHub releases..."
        local resvg_ver
        resvg_ver="$(github_latest_release nickel-org resvg 2>/dev/null || echo "")"
        if [ -z "$resvg_ver" ]; then
            # Fallback: try linebender/resvg (the actual upstream)
            resvg_ver="$(github_latest_release linebender resvg)"
        fi

        local resvg_arch
        case "$DOTFILES_ARCH" in
            x86_64)  resvg_arch="x86_64" ;;
            aarch64) resvg_arch="aarch64" ;;
        esac

        local resvg_url="https://github.com/nickel-org/resvg/releases/download/${resvg_ver}/resvg-${resvg_ver}-${resvg_arch}-unknown-linux-gnu.tar.gz"
        local resvg_tmp
        resvg_tmp="$(mktemp -d)"
        if curl -fsSL "$resvg_url" | tar xz -C "$resvg_tmp" 2>/dev/null; then
            mv "${resvg_tmp}"/resvg*/resvg "${HOME}/.local/bin/resvg" 2>/dev/null \
                || mv "${resvg_tmp}/resvg" "${HOME}/.local/bin/resvg" 2>/dev/null
            chmod +x "${HOME}/.local/bin/resvg"
            log_success "resvg installed"
        else
            log_warn "Could not auto-install resvg. SVG preview in Yazi will be unavailable."
        fi
        rm -rf "$resvg_tmp"
    fi
}

_install_nerd_font_linux() {
    local font_dir="${HOME}/.local/share/fonts"
    if [ -d "$font_dir" ] && ls "$font_dir"/Symbols*Nerd* &>/dev/null; then
        log_success "Nerd Font symbols already installed"
        return
    fi

    log_info "Installing Nerd Font (Symbols Only)..."
    local nf_version
    nf_version="$(github_latest_release ryanoasis nerd-fonts)"

    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${nf_version}/NerdFontsSymbolsOnly.zip"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    curl -fsSL -o "${tmp_dir}/nf.zip" "$url"
    mkdir -p "$font_dir"
    unzip -q "${tmp_dir}/nf.zip" -d "$font_dir"
    rm -rf "$tmp_dir"

    # Refresh font cache
    if command_exists fc-cache; then
        fc-cache -f "$font_dir"
    fi
    log_success "Nerd Font symbols installed"
}
