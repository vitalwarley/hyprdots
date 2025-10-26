# Hyprland Configuration Structure

This directory contains **user customizations** for HyDE (HyprDE). The HyDE framework manages most configuration files automatically.

## Architecture

HyDE uses a two-tier configuration system:

1. **System templates** in `~/.local/share/hyde/` - Managed by HyDE
2. **User customizations** in `~/.config/hypr/` (this directory) - Your changes

## Files in This Repository

### User-Editable Files (version controlled)

These are **your** configuration files. Edit freely:

- **`userprefs.conf`** - Your personal Hyprland preferences (keybinds, animations, etc.)
- **`monitors.conf`** - Monitor configuration
- **`keybindings.conf`** - Custom keyboard shortcuts (if you want to override defaults)
- **`windowrules.conf`** - Custom window rules
- **`hyde.conf`** - HyDE variable overrides (apps, environment, themes)

### Custom Resources (version controlled)

- **`animations/`** - Custom animation presets
- **`hyprlock/`** - Custom lock screen layouts
- **`workflows/`** - Custom workflow configurations
- **`scripts/`** - Your custom scripts
- **`autostart/`** - Custom autostart scripts

## Files NOT in This Repository

These files **must exist** in `~/.config/hypr/` at runtime but are **not version controlled** because they're managed by HyDE:

### Required System Files (in .gitignore)

- **`hyprland.conf`** - Main entry point (sources your custom configs)
- **`workflows.conf`** - Auto-generated workflow selector
- **`animations.conf`** - Animation system configuration
- **`shaders.conf`** - Shader configuration
- **`nvidia.conf`** - NVIDIA-specific settings
- **`themes/`** - Generated theme files (wallbash colors)

These files are copied from HyDE templates during installation/updates.

## Setup Instructions

After cloning this repository:

1. **Copy required files from HyDE template:**
   ```bash
   cd ~/dev/hyprdots/HyDE/Configs/.config/hypr
   cp hyprland.conf workflows.conf animations.conf shaders.conf nvidia.conf ~/.config/hypr/
   cp -r themes ~/.config/hypr/
   ```

2. **Or use HyDE's restore command** (if available):
   ```bash
   hyde restore
   ```

## How to Customize

### Change Hyprland Settings
Edit **`userprefs.conf`** - this is your main customization file.

### Override HyDE Variables
Edit **`hyde.conf`** to change:
- Default applications (`$BROWSER`, `$TERMINAL`, etc.)
- Startup commands (`$start.*`)
- Environment variables (`$env.*`)
- Theme settings (GTK, icons, cursors, fonts)

### Custom Keybindings
- HyDE provides defaults in `~/.local/share/hyde/keybindings.conf`
- Override specific bindings in **`userprefs.conf`**
- Or edit **`keybindings.conf`** if you want full control

### Monitor Configuration
Edit **`monitors.conf`** for display settings.

### Window Rules
Add rules to **`windowrules.conf`**.

## Troubleshooting

### "Config error: source= globbing error"

This means required HyDE-managed files are missing. Copy them from the HyDE template:

```bash
# Check what's missing
hyprctl configerrors

# Copy from template
cp ~/dev/hyprdots/HyDE/Configs/.config/hypr/<missing-file> ~/.config/hypr/
```

### Verify Configuration
```bash
# Check for errors
hyprctl configerrors

# Reload configuration
hyprctl reload
```

## Documentation

- [HyDE Documentation](https://hydeproject.pages.dev/en/configuring/hyprland/)
- [Hyprland Wiki](https://wiki.hyprland.org/)
