# Hyprland Custom Scripts

This directory contains custom scripts for Hyprland. The scripts are referenced in the Hyprland configuration using the `$customScripts` variable.

```hypr
$customScripts = ~/.config/hypr/scripts
```

## Move Window to Workspace Script

### Description
The `move_window_to_workspace.sh` script allows you to move a specific window to a target workspace in Hyprland.

### Usage
```bash
# Move a specific window by class or title
./move_window_to_workspace.sh [window_class_or_title] [workspace]

# Move the active window (simpler form)
./move_window_to_workspace.sh [workspace]
```

#### Parameters
- `window_class_or_title`: (Optional) The window class or title (case-insensitive). If omitted, the active window is used.
- `workspace`: The target workspace number or "special" for the scratch workspace.

#### Examples
1. Move the currently active window to workspace 2:
```bash
./move_window_to_workspace.sh 2
```

2. Move all Firefox windows to workspace 3:
```bash
./move_window_to_workspace.sh firefox 3
```

3. Move a window with a specific title to workspace 5:
```bash
./move_window_to_workspace.sh "YouTube - Mozilla Firefox" 5
```

### Keybindings
The script has been integrated with direct keybindings:

- **Super + Alt + Shift + [1-0]**: Move the active window to workspace 1-10

For example:
- **Super + Alt + Shift + 3** moves the active window to workspace 3
- **Super + Alt + Shift + 9** moves the active window to workspace 9
