#!/bin/bash
# Hyprland dotfiles installer for Arch Linux.
# Usage: ./install.sh [--no-aur] [--no-upgrade] [--help]
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
USE_AUR=1
UPGRADE=1

for arg in "$@"; do
    case "$arg" in
        --no-aur)     USE_AUR=0 ;;
        --no-upgrade) UPGRADE=0 ;;
        -h|--help)
            sed -n '2,3p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '    ! %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

# Read a package list, dropping comments and blank lines
read_list() { grep -vE '^\s*(#|$)' "$1"; }

# Symlink repo file into place, backing up anything already there
link() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "$dest.bak"
        warn "Backed up existing $dest to $dest.bak"
    fi
    ln -sfn "$src" "$dest"
}

# ---------------------------------------------------------------- checks
log "Checking prerequisites"
[ "$EUID" -ne 0 ] || die "Run as your normal user, not root. The script uses sudo when needed."
command -v pacman >/dev/null 2>&1 || die "This installer is for Arch Linux (pacman not found)."
command -v sudo   >/dev/null 2>&1 || die "sudo is not installed. As root run: pacman -S sudo, then add your user to the wheel group."

# Ping is often blocked, so test with HTTPS instead
curl -sSI --max-time 8 https://archlinux.org >/dev/null 2>&1 \
    || die "No internet access (HTTPS to archlinux.org failed). Check your network and clock."

sudo -v

# ---------------------------------------------------------------- packages
log "Installing official repo packages"
if [ "$UPGRADE" -eq 1 ]; then
    # Full upgrade avoids partial-upgrade breakage on Arch
    read_list "$DOTFILES_DIR/packages/pacman.txt" | sudo pacman -Syu --needed --noconfirm -
else
    read_list "$DOTFILES_DIR/packages/pacman.txt" | sudo pacman -S --needed --noconfirm -
fi

log "Installing optional packages (official repos first, then AUR)"
AUR_PENDING=()
while read -r pkg; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "$pkg"
    else
        AUR_PENDING+=("$pkg")
    fi
done < <(read_list "$DOTFILES_DIR/packages/aur.txt")

if [ "${#AUR_PENDING[@]}" -gt 0 ]; then
    if [ "$USE_AUR" -eq 0 ]; then
        warn "Skipping AUR packages: ${AUR_PENDING[*]}"
    else
        if ! command -v yay >/dev/null 2>&1; then
            log "Building yay (AUR helper)"
            tmp="$(mktemp -d)"
            git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
            (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
            rm -rf "$tmp"
        fi
        for pkg in "${AUR_PENDING[@]}"; do
            yay -S --needed --noconfirm "$pkg" || warn "Could not install $pkg from the AUR"
        done
    fi
fi

# ---------------------------------------------------------------- services
log "Enabling services"
sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 || warn "Could not enable bluetooth (no adapter?)"
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1 \
    || warn "Could not enable PipeWire user services now, they will start on next login"

# ---------------------------------------------------------------- configs
log "Linking configs"
link "$DOTFILES_DIR/hypr/hyprland.lua"            "$CONFIG/hypr/hyprland.lua"
link "$DOTFILES_DIR/waybar/config"                "$CONFIG/waybar/config"
link "$DOTFILES_DIR/waybar/style.css"             "$CONFIG/waybar/style.css"
link "$DOTFILES_DIR/waybar/scripts/datetime.sh"   "$CONFIG/waybar/scripts/datetime.sh"
link "$DOTFILES_DIR/kitty/kitty.conf"             "$CONFIG/kitty/kitty.conf"
chmod +x "$DOTFILES_DIR/waybar/scripts/datetime.sh"

log "Generating hyprpaper.conf for $HOME"
mkdir -p "$CONFIG/hypr" "$HOME/Pictures"
[ -e "$CONFIG/hypr/hyprpaper.conf" ] && [ ! -e "$CONFIG/hypr/hyprpaper.conf.bak" ] \
    && cp "$CONFIG/hypr/hyprpaper.conf" "$CONFIG/hypr/hyprpaper.conf.bak" || true
sed "s|__HOME__|$HOME|g" "$DOTFILES_DIR/hypr/hyprpaper.conf.template" > "$CONFIG/hypr/hyprpaper.conf"

# ---------------------------------------------------------------- themes
log "Catppuccin Mocha themes"
mkdir -p "$CONFIG/kitty/themes" "$CONFIG/ranger/colorschemes"
[ -f "$CONFIG/kitty/themes/mocha.conf" ] || curl -sSL -o "$CONFIG/kitty/themes/mocha.conf" \
    https://raw.githubusercontent.com/catppuccin/kitty/main/themes/mocha.conf
[ -f "$CONFIG/ranger/colorschemes/catppuccin_mocha.py" ] || curl -sSL -o "$CONFIG/ranger/colorschemes/catppuccin_mocha.py" \
    https://raw.githubusercontent.com/catppuccin/ranger/main/themes/mocha.py

# ---------------------------------------------------------------- ranger
log "Configuring ranger"
[ -f "$CONFIG/ranger/rc.conf" ] || ranger --copy-config=all >/dev/null 2>&1 || true
touch "$CONFIG/ranger/rc.conf"
if ! grep -q "catppuccin_mocha" "$CONFIG/ranger/rc.conf"; then
    { echo; cat "$DOTFILES_DIR/ranger/rc.conf.local"; } >> "$CONFIG/ranger/rc.conf"
fi

# ---------------------------------------------------------------- zsh
log "Configuring ZSH"
touch "$HOME/.zshrc"
if ! grep -q "ranger-cd" "$HOME/.zshrc"; then
    { echo; cat "$DOTFILES_DIR/zsh/zshrc.append"; } >> "$HOME/.zshrc"
fi
if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
    chsh -s "$(command -v zsh)" || warn "Could not change shell, run: chsh -s $(command -v zsh)"
fi

# ---------------------------------------------------------------- done
cat << MSG

==> Done.

Before you start Hyprland:
  1. Put a wallpaper at ~/Pictures/wallpaper.jpg
  2. Install a GPU driver if you have not already (mesa is pulled in for most
     setups, NVIDIA needs nvidia-open and extra Hyprland setup)
  3. Log out, log in on a TTY and run: Hyprland

Once it is running:
  hyprctl monitors       # change eDP-1 in hypr/hyprland.lua and hyprpaper if needed
  hyprctl configerrors   # shows any Lua config problems

Configs are symlinked, so edit them inside this repo and commit as normal.
MSG
