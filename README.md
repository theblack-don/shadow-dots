# Shadow Dots

A minimal Hyprland desktop environment for CachyOS/Arch Linux using [DCLI](https://gitlab.com/theblackdon/dcli) and bundled with the [Shell Switcher](https://gitlab.com/theblackdon/shell-switch) for toggling between **Dank Material Shell (DMS)** and **Noctalia Shell**.

## Install

```bash
git clone https://github.com/theblack-don/shadow-dots.git
cd shadow-dots
./install.sh
```

The installer will:
1. Install `dcli` from the AUR if it is missing
2. Copy the full `dcli-config` into `~/.config/`
3. Validate the config with `dcli validate`

Then run `dcli sync` to install packages and apply dotfiles.

After syncing, log out and select Hyprland. Noctalia starts by default. Press **Super+Space** for the launcher, or run `shell-switch` to toggle between DMS and Noctalia.
# shadow-dots
