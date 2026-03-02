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

# --- apt-get update wrapper ---

# apt_update()
#   Runs `sudo apt-get update -qq` unless DOTFILES_SKIP_APT_UPDATE=1.
apt_update() {
    if [ "${DOTFILES_SKIP_APT_UPDATE:-0}" = "1" ]; then
        log_warn "Skipping apt-get update (DOTFILES_SKIP_APT_UPDATE=1)"
        return 0
    fi
    sudo apt-get update -qq
}

# --- Interactive Tool Selector ---

# ensure_gum()
#   Installs gum if not already present (brew on macOS, GitHub release on Linux).
ensure_gum() {
    if command_exists gum; then
        log_success "gum already installed"
        return 0
    fi

    log_info "Installing gum..."
    case "$DOTFILES_OS" in
        macos)
            brew install gum
            ;;
        *)
            local version
            version="$(github_latest_release charmbracelet gum)"
            local arch_suffix
            case "$DOTFILES_ARCH" in
                x86_64)  arch_suffix="x86_64" ;;
                aarch64) arch_suffix="arm64" ;;
                *)
                    log_error "Unsupported architecture for gum: $DOTFILES_ARCH"
                    return 1
                    ;;
            esac
            local url="https://github.com/charmbracelet/gum/releases/download/${version}/gum_${version#v}_linux_${arch_suffix}.tar.gz"
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            curl -fsSL "$url" | tar xz -C "$tmp_dir"
            mv "${tmp_dir}"/gum_*/gum "${HOME}/.local/bin/gum"
            chmod +x "${HOME}/.local/bin/gum"
            rm -rf "$tmp_dir"
            ;;
    esac
    log_success "gum installed"
}

# _SELECTED_TOOLS -- newline-separated list populated by select_tools()
_SELECTED_TOOLS=""

# select_tools()
#   Presents an interactive multi-select via gum. Falls back to all items
#   when gum is unavailable or stdin is not a TTY (CI).
select_tools() {
    local -a items=(
        "Ghostty -- GPU-accelerated terminal"
        "lazygit -- TUI git client"
        "Yazi -- Terminal file manager"
        "Claude Code -- Config, settings, and agents"
        "Shell integration -- zsh aliases (lg, y, zoxide)"
    )
    local all_selected
    all_selected="$(printf '%s\n' "${items[@]}")"

    if ! command_exists gum || [ ! -t 0 ]; then
        log_info "Non-interactive mode: selecting all items"
        _SELECTED_TOOLS="$all_selected"
        return 0
    fi

    log_info "Select what to install (space to toggle, enter to confirm):"
    _SELECTED_TOOLS="$(gum choose --no-limit \
        --selected "${items[0]},${items[1]},${items[2]},${items[3]},${items[4]}" \
        "${items[@]}")" || true

    if [ -z "$_SELECTED_TOOLS" ]; then
        log_warn "Nothing selected. No tools or configs will be installed."
    fi
}

# is_selected(tool_name)
#   Returns 0 if the tool was selected, 1 otherwise.
is_selected() {
    echo "$_SELECTED_TOOLS" | grep -qF "$1"
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
