#!/bin/bash

# System-wide terminal setup: installs ZSH and the essentials, then applies the
# terminal ZSH config to every user, existing and future. No GUI packages.
# Run as a user with sudo, or as root. Safe to run again.
# Usage: ./install-terminal.sh [--no-packages] [--help]
#   --no-packages  skip the package install

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_CONF="$DOTFILES_DIR/zsh/zshrc.terminal"
DEST_CONF=/etc/zsh/terminal-env.zsh
GLOBAL_RC=/etc/zsh/zshrc
MARKER_BEGIN="# BEGIN terminal-env"
MARKER_END="# END terminal-env"
INSTALL_PKGS=1

# Terminal essentials only: nothing here needs a display
PKGS=(zsh git curl tmux ranger vim htop jq ripgrep unzip)

for arg in "$@"; do
  case "$arg" in
    --no-packages) INSTALL_PKGS=0 ;;
    -h|--help)
      sed -n '3,8p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- checks
[ -f "$SRC_CONF" ] || die "zsh/zshrc.terminal not found. Run this from inside the repo."

# System-wide changes need root, so re-run under sudo if needed
if [ "$EUID" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || die "Not root and sudo is not installed."
  log "Re-running with sudo"
  exec sudo "${BASH_SOURCE[0]}" "$@"
fi

# ---------------------------------------------------------------- packages
if [ "$INSTALL_PKGS" -eq 1 ]; then
  if command -v apt-get >/dev/null 2>&1; then
    PM=apt
  elif command -v pacman >/dev/null 2>&1; then
    PM=pacman
  else
    die "Neither apt nor pacman found."
  fi

  curl -sSI --max-time 8 https://github.com >/dev/null 2>&1 \
    || die "No internet access (HTTPS to github.com failed). Check your network and clock."

  log "Installing packages: ${PKGS[*]}"
  if [ "$PM" = apt ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"
  else
    # Full upgrade avoids partial-upgrade breakage on Arch
    pacman -Syu --needed --noconfirm "${PKGS[@]}"
  fi
else
  warn "Skipping package install, ZSH must already be installed"
fi

ZSH_BIN="$(command -v zsh || true)"
[ -n "$ZSH_BIN" ] || die "zsh is not installed. Re-run without --no-packages."

grep -qx "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" >> /etc/shells

# ---------------------------------------------------------------- shared config
log "Installing shared ZSH config for all users"

install -d -m 755 /etc/zsh
install -m 644 "$SRC_CONF" "$DEST_CONF"

# Hook it in at the end of the global zshrc so it overrides distro defaults
touch "$GLOBAL_RC"
if ! grep -qF "$MARKER_BEGIN" "$GLOBAL_RC"; then
  {
    echo
    echo "$MARKER_BEGIN"
    echo "[ -r $DEST_CONF ] && . $DEST_CONF"
    echo "$MARKER_END"
  } >> "$GLOBAL_RC"
else
  echo "  $GLOBAL_RC already hooked in, config file refreshed"
fi

# ---------------------------------------------------------------- future users
log "Setting ZSH as the default for future users"

# An existing ~/.zshrc stops ZSH launching its first-run setup wizard
if [ ! -e /etc/skel/.zshrc ]; then
  printf '%s\n' "# Personal ZSH settings. Shared defaults load first from $DEST_CONF." > /etc/skel/.zshrc
fi

if [ -f /etc/adduser.conf ]; then
  if grep -q '^DSHELL=' /etc/adduser.conf; then
    sed -i "s|^DSHELL=.*|DSHELL=$ZSH_BIN|" /etc/adduser.conf
  else
    echo "DSHELL=$ZSH_BIN" >> /etc/adduser.conf
  fi
fi
if command -v useradd >/dev/null 2>&1; then
  useradd -D -s "$ZSH_BIN" >/dev/null
fi

# ---------------------------------------------------------------- existing users
log "Updating existing users (UID 1000 and above)"

while IFS=: read -r user uid home shell; do
  [ -d "$home" ] || { warn "$user: no home directory, skipped"; continue; }

  if [ ! -e "$home/.zshrc" ]; then
    install -o "$user" -g "$(id -gn "$user")" -m 644 /dev/null "$home/.zshrc"
  fi

  # Only swap ordinary login shells, so nologin and restricted shells are left alone
  case "$shell" in
    */bash|*/sh|*/dash)
      usermod -s "$ZSH_BIN" "$user"
      echo "  $user: shell changed from $shell to $ZSH_BIN" ;;
    *)
      echo "  $user: shell $shell left alone" ;;
  esac
done < <(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1":"$3":"$6":"$7}')

# ---------------------------------------------------------------- done
cat << MSG

==> Done.

Users must log out and back in for the new shell to apply.
Root and system accounts are untouched, but anyone who runs zsh gets the shared config.
Safe to run again.

MSG
