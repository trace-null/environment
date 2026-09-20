# Hyprland dotfiles (Arch Linux)

A Catppuccin Mocha Hyprland setup with a frosted glass Waybar, Kitty, ranger
and a plain ZSH prompt.

## Requirements

- Arch Linux (fresh install is fine) with a working network connection
- A normal user with sudo access
- Hyprland 0.55 or later, because the config uses the Lua format
  (`hyprland.lua`) rather than the older `hyprland.conf`

## Install

```bash
git clone https://github.com/trace-null/environment.git ~/environment
cd ~/environment
./install.sh
```

Options:

- `--no-aur` skips packages that need the AUR
- `--no-upgrade` installs packages without a full system upgrade first

## What the installer does

1. Checks it is not running as root, that pacman and sudo exist and that HTTPS
   works (ping is often blocked on guest networks, so it is not used)
2. Runs a full upgrade and installs everything in `packages/pacman.txt`
3. Installs `packages/aur.txt` from the official repos if available, otherwise
   builds `yay` and uses the AUR
4. Enables Bluetooth and PipeWire
5. Symlinks the configs into `~/.config`, backing up anything already there
   as `.bak`
6. Generates `hyprpaper.conf` for your home directory
7. Downloads the Catppuccin Mocha themes for Kitty and ranger
8. Appends the ranger and ZSH snippets once, and sets ZSH as your shell

The installer can safely be run again.

## After installing

- Put a wallpaper at `~/Pictures/wallpaper.jpg`
- Install a GPU driver if you have not already
- Log in on a TTY and run `Hyprland`
- Run `hyprctl monitors` and change `eDP-1` in `hypr/hyprland.lua` and
  `hypr/hyprpaper.conf.template` if your output has a different name
- Run `hyprctl configerrors` to check for config problems

## Layout

```
install.sh
packages/pacman.txt        official repo packages
packages/aur.txt           hyprlauncher and wlogout
hypr/hyprland.lua          main config
hypr/hyprpaper.conf.template
waybar/config              modules
waybar/style.css           glass pill styling
waybar/scripts/datetime.sh clock with 1st, 2nd, 3rd suffixes
kitty/kitty.conf
ranger/rc.conf.local       appended to ranger's rc.conf
zsh/zshrc.append           appended to ~/.zshrc
```

## Key bindings

| Keys | Action |
| --- | --- |
| Super + Return | Terminal (Kitty) |
| Super + Space | Launcher (hyprlauncher) |
| Super + E | ranger in Kitty |
| Super + Q | Close window |
| Super + M | Exit Hyprland |
| Super + V | Toggle floating |
| Super + 1 to 0 | Switch workspace |
| Super + Shift + 1 to 0 | Move window to workspace |

## Known issues

- `hyprlauncher` has a heavy dependency chain and may not be packaged. If it
  is missing, replace `hyprlauncher` with `rofi -show drun` in
  `hypr/hyprland.lua` and `waybar/config`. rofi is installed as a fallback.
- Dunst only supports showing the last notification and clearing all of them.
  A proper history panel would need `swaync`.

## Licence

MIT
