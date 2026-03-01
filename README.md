# dotfiles

Bootstrap a new macOS or Linux machine with the TUI trio: **Ghostty**, **lazygit**, and **Yazi**.

One command installs everything and symlinks configs from this repo, so edits stay version-controlled.

## Quick Start

```bash
git clone https://github.com/daniFloresR/dotfiles.git ~/repos/dotfiles
cd ~/repos/dotfiles
./install.sh
```

## What It Installs

| Tool | What | macOS | Linux |
|------|------|-------|-------|
| [Ghostty](https://ghostty.org) | GPU-accelerated terminal | Homebrew cask | PPA / COPR / pacman |
| [lazygit](https://github.com/jesseduffield/lazygit) | TUI git client | Homebrew | GitHub release binary |
| [Yazi](https://yazi-rs.github.io) | Terminal file manager | Homebrew | GitHub release binary |

Yazi dependencies (fd, ripgrep, fzf, zoxide, 7z, resvg, imagemagick, Nerd Font) are installed automatically.

## Shell Integration

The installer appends three blocks to `~/.zshrc` (idempotent, marker-guarded):

- `lg` alias for lazygit
- `y` function for Yazi with cd-on-exit
- zoxide shell init

## Configs

Configs live in `config/` and are symlinked to their expected locations:

| Config | Symlink Target (macOS) | Symlink Target (Linux) |
|--------|----------------------|----------------------|
| `config/ghostty/config` | `~/Library/Application Support/com.mitchellh.ghostty/config` | `~/.config/ghostty/config` |
| `config/lazygit/config.yml` | `~/Library/Application Support/lazygit/config.yml` | `~/.config/lazygit/config.yml` |
| `config/yazi/yazi.toml` | `~/.config/yazi/yazi.toml` | `~/.config/yazi/yazi.toml` |

Edit the files in this repo -- changes apply immediately (or after config reload).

## Supported Platforms

- macOS (Apple Silicon and Intel)
- Ubuntu / Debian
- Fedora
- Arch Linux

## Design

- **Symlinks, not copies** -- standard dotfiles pattern.
- **Marker-based .zshrc blocks** -- only manages its own blocks, won't overwrite NVM/Docker/Cargo/etc.
- **Idempotent** -- safe to re-run. Skips installed tools, existing symlinks, existing shell blocks.
- **Backup before overwrite** -- existing configs renamed to `*.backup.YYYYMMDDHHMMSS`.
- **No sudo on macOS** -- everything goes through Homebrew. Linux uses sudo only for package managers.
