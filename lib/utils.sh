#!/usr/bin/env bash
# Shared utility functions for dotfiles bootstrap.

# --- OS / Arch Detection ---

detect_os() {
    case "$(uname -s)" in
        Darwin)
            DOTFILES_OS="macos"
            ;;
        Linux)
            if [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian) DOTFILES_OS="ubuntu" ;;
                    fedora)        DOTFILES_OS="fedora" ;;
                    arch|endeavouros|manjaro) DOTFILES_OS="arch" ;;
                    *)             DOTFILES_OS="unknown" ;;
                esac
            else
                DOTFILES_OS="unknown"
            fi
            ;;
        *)
            DOTFILES_OS="unknown"
            ;;
    esac
    export DOTFILES_OS
    log_info "Detected OS: $DOTFILES_OS"
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) DOTFILES_ARCH="x86_64" ;;
        aarch64|arm64) DOTFILES_ARCH="aarch64" ;;
        *)             DOTFILES_ARCH="unknown" ;;
    esac
    export DOTFILES_ARCH
    log_info "Detected arch: $DOTFILES_ARCH"
}

# --- Logging ---

log_info()    { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
log_warn()    { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
log_error()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }
log_success() { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }

# --- Helpers ---

command_exists() {
    command -v "$1" &>/dev/null
}

ensure_brew() {
    if command_exists brew; then
        log_success "Homebrew already installed"
        return
    fi
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Ensure brew is on PATH for the rest of this session
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    log_success "Homebrew installed"
}

# symlink_config(source_relative, target_path)
#   source_relative: path relative to $DOTFILES_DIR (e.g. config/ghostty/config)
#   target_path:     absolute path where the symlink should be created
symlink_config() {
    local source_rel="$1"
    local target="$2"
    local source="${DOTFILES_DIR}/${source_rel}"

    # Already a correct symlink
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        log_success "Symlink already correct: $target"
        return
    fi

    # Back up existing file/dir (not a symlink to us)
    if [ -e "$target" ] || [ -L "$target" ]; then
        local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
        log_warn "Backing up existing $target -> $backup"
        mv "$target" "$backup"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    log_success "Symlinked $target -> $source"
}

# append_block_if_missing(marker, block_text)
#   Appends a tagged block to ~/.zshrc if the marker is not already present.
append_block_if_missing() {
    local marker="$1"
    local block_text="$2"
    local zshrc="${HOME}/.zshrc"

    # Create .zshrc if it doesn't exist
    touch "$zshrc"

    if grep -qF "[dotfiles:${marker}] BEGIN" "$zshrc"; then
        log_success "Shell block [dotfiles:${marker}] already present in .zshrc"
        return
    fi

    {
        echo ""
        echo "# [dotfiles:${marker}] BEGIN"
        echo "$block_text"
        echo "# [dotfiles:${marker}] END"
    } >> "$zshrc"
    log_success "Added [dotfiles:${marker}] block to .zshrc"
}

# github_latest_release(owner, repo)
#   Prints the latest release tag name (e.g. "v0.5.0").
github_latest_release() {
    local owner="$1"
    local repo="$2"
    curl -fsSL "https://api.github.com/repos/${owner}/${repo}/releases/latest" \
        | grep '"tag_name"' \
        | head -1 \
        | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/'
}
