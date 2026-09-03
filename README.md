# Dotfiles

Sway desktop config (waybar, mako, wofi, bash, terminals, nvim, …).

## Screenshots

![Sway desktop with the system menu open](screenshots/desktop.webp)
*The system menu (`Super+Escape`) over the desktop — waybar on top: workspaces, clock, and the tray (keyboard layout, bluetooth, network, volume, settings, battery).*

![btop in alacritty, tiled by sway](screenshots/btop.webp)
*btop in alacritty, with a mako notification for a fresh screenshot.*

## Install (after packages)

```bash
# From arch setup (automatic), or manually:
cd ~/dotfiles
./install.sh
```

Uses **GNU stow** to symlink packages into `$HOME` / `.config`.

## Stow one package

```bash
stow nvim
stow sway
```

## Pair with system bootstrap

System packages + services: [arch](https://github.com/alekskin/arch) (`./setup.sh`).

## Layout

Each top-level directory is a stow package, e.g.:

```text
sway/.config/sway/...
bash/.bashrc
waybar/.config/waybar/...
```
