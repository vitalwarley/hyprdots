# Changelog

All notable changes to this dotfiles repository are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- **shell**: HyDE `env.zsh` source guard to prevent double-sourcing that clobbers PATH entries from `conf.d` scripts (e.g., nvm node bin added by `01-dev-paths.zsh`). Made `$HOME/.local/bin` PATH prepend idempotent.

### Added
- **shell**: `patch-hyde-env.sh` — reapplyable script to re-patch `env.zsh` after `hyde update` overwrites it.

## 2025-02-08

### Added
- `screenpipe.desktop` entry and session-wide PATH config (`fab63da`)
- Versioned zsh configs with secret management (`0fe9185`)

## 2025-02-06

### Added
- External monitor brightness control via DDC/CI (`696f6cd`)

### Fixed
- Hyprland 0.53+ windowrule syntax (`ee5805f`)

## 2025-01-29

### Added
- Kitty as Thunar terminal emulator (`52d76b1`)

## 2025-01-21

### Added
- Waybar workspaces to left pill with passthrough option (`f172b54`)
- Workspace notification script (`3a4d905`)

### Changed
- Ignore wallbash-generated `waybar/theme.css` (`9345d0f`)
- Switch to UFAL monitor layout (`597f492`)

## 2025-01-15

### Added
- Keybinding to reload Hyprland config (`43e4a63`)
- Hyprlock configuration (`44c1175`)
- Okular window rule (`3381331`)

### Fixed
- Relative symlink path for HyDE directory (`d4566bf`)
- Window rules for Hyprland 0.52.1 compatibility (`4691075`)

## 2025-01-10

### Added
- Comprehensive Hyprland configuration structure docs (`df8ec43`)
- Workspace assignments for monitors (`9ecaf30`)
- Initial Hyprland configuration (`c650541`)

### Changed
- Removed HyDE-managed template files from version control (`439b4b6`)
