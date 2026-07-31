# Dotfiles

Sway desktop config (waybar, mako, wofi, bash, terminals, nvim, …).

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

System packages + services: [arch](https://github.com/BabkinAleksandr/arch) (`./setup.sh`).

## Layout

Each top-level directory is a stow package, e.g.:

```text
sway/.config/sway/...
bash/.bashrc
waybar/.config/waybar/...
```
