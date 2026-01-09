# Hyprdots

A Hyprland configuration based on the HyDE Project.

## Configuration Structure

HyDE's Hyprland configuration is structured into three main sections:

### 1. Boilerplate
- Default HyDE configuration
- Located at `$XDG_DATA_HOME/share/hyde/hyprland.conf`
- Not recommended to modify directly

### 2. Overrides
- For overriding default HyDE configuration
- Used to modify startup apps, environment variables, etc.
- Located at `$XDG_CONFIG_HOME/hypr/hyde.conf`

### 3. Users
- For personal configuration
- Split into separate files:
  - `keybindings.conf` - Keyboard shortcuts
  - `windowrules.conf` - Window behavior rules
  - `monitors.conf` - Monitor configuration
  - `userprefs.conf` - Personal Hyprland preferences

## SSH Agent Configuration

This repository includes a systemd user service for automatically starting the SSH agent:

1. Link the SSH agent systemd service file:
   ```bash
   mkdir -p ~/.config/systemd/user/
   ln -s /path/to/hyprdots/.config/systemd/user/ssh-agent.service ~/.config/systemd/user/
   ```

2. Link the environment variables configuration:
   ```bash
   mkdir -p ~/.config/environment.d/
   ln -s /path/to/hyprdots/.config/environment.d/ssh-agent.conf ~/.config/environment.d/
   ```

3. Enable and start the service:
   ```bash
   systemctl --user enable ssh-agent.service
   systemctl --user start ssh-agent.service
   ```

This will ensure your SSH agent starts automatically and remains available for all applications.

## Adding Custom Scripts

There are several ways to add your custom scripts to the HyDE environment:

### 1. Using `$start.` Variables in hyde.conf

Add your scripts as startup items in `~/.config/hypr/hyde.conf`:

```hypr
# Add your custom scripts to run at startup
$start.MY_CUSTOM_SCRIPT=/path/to/your/script.sh
$start.ANOTHER_SCRIPT=/path/to/another/script.sh
```

### 2. Adding to userprefs.conf

For scripts that should be part of your configuration but aren't necessarily startup items:

```hypr
# Custom script execution
exec-once = /path/to/your/script.sh
```

### 3. Creating a Scripts Directory

Create a dedicated scripts directory:

```bash
mkdir -p ~/.config/hypr/scripts
chmod +x ~/.config/hypr/scripts/myscript.sh
```

Reference them in your configuration:

```hypr
exec-once = ~/.config/hypr/scripts/myscript.sh
```

### 4. Adding Custom Keybindings

To trigger scripts with keyboard shortcuts, add them to `keybindings.conf`:

```hypr
# Custom script keybinding
bind = $mainMod, F12, exec, ~/.config/hypr/scripts/myscript.sh
```

## Best Practices for Scripts

1. **Create a dedicated directory**: Keep scripts organized in a specific directory
2. **Make scripts executable**: Use `chmod +x script.sh`
3. **Use absolute paths**: When referencing scripts in config files
4. **Add shebang lines**: Start scripts with proper shebangs (e.g., `#!/bin/bash`)
5. **Test scripts independently**: Ensure they work before adding to Hyprland configuration

## Making .desktop Files Executable

When creating or modifying `.desktop` files (for example, to customize application launch options), you must ensure the file is marked as executable. Otherwise, some desktop environments and launchers may ignore or fail to use your custom `.desktop` file.

To make a `.desktop` file executable, run:

```sh
chmod +x ~/.local/share/applications/your-app.desktop
```

Replace `your-app.desktop` with the actual file name. This step is essential for your changes to take effect when launching applications via menus, launchers, or tools like `rofi`.

## Thunar Configuration

The `xfce4/` folder contains configuration for Thunar file manager when used outside of the XFCE desktop environment.

### Terminal Emulator

`xfce4/helpers.rc` configures the terminal emulator used by Thunar's "Open Terminal Here" action. To use it:

```bash
ln -s /path/to/hyprdots/xfce4/helpers.rc ~/.config/xfce4/helpers.rc
```

This sets kitty as the default terminal for Thunar on Hyprland.