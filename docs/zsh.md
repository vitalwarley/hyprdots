# Zsh Configuration Guide

Comprehensive guide to zsh shell configuration, covering standard zsh behavior, file loading order, and integration with HyDE.

**Related Documentation:**
- [HyDE Configuration](./hyde.md) - HyDE desktop environment integration
- [Shell Directory](../shell/README.md) - Versioned shell configs and setup

---

## Table of Contents

- [Overview](#overview)
- [File Loading Order](#file-loading-order)
- [Configuration Files](#configuration-files)
- [Environment Variables](#environment-variables)
- [Aliases](#aliases)
- [Functions](#functions)
- [Keybindings](#keybindings)
- [History Configuration](#history-configuration)
- [Best Practices](#best-practices)

---

## Overview

### What is Zsh?

**Zsh** (Z Shell) is a powerful Unix shell with advanced features:
- Command completion
- Spell checking
- Path expansion
- Themeable prompts
- Plugin system
- Extensive customization

### Configuration Philosophy

In this setup:
- **HyDE manages**: Core zsh behavior, plugins, prompts
- **You manage**: Personal configs, PATH, aliases, tools
- **Separation**: Clear boundary between managed and user files

See [hyde.md](./hyde.md) for HyDE-specific configuration.

---

## File Loading Order

### Standard Zsh Startup Sequence

Zsh loads files in this order (for interactive login shells):

```mermaid
graph TB
    A[Zsh Starts] --> B{Login Shell?}
    B -->|Yes| C[/etc/zshenv]
    B -->|No| C
    C --> D[~/.zshenv]
    D --> E{Login Shell?}
    E -->|Yes| F[/etc/zprofile]
    E -->|No| G{Interactive?}
    F --> G
    G -->|Yes| H[/etc/zshrc]
    G -->|No| END
    H --> I[~/.zshrc]
    I --> J{Login Shell?}
    J -->|Yes| K[/etc/zlogin]
    J -->|No| END
    K --> L[~/.zlogin]
    L --> END[Shell Ready]

    style D fill:#9f9
    style I fill:#9f9
```

### This Setup's Loading Order

With HyDE integration, the actual loading flow is:

```
1. ~/.zshenv
   └─> Sets ZDOTDIR to ~/.config/zsh
   └─> Sources ~/.config/zsh/.zshenv

2. ~/.config/zsh/.zshenv (HyDE)
   └─> Sources conf.d/*.zsh files
       └─> 00-hyde.zsh
           └─> hyde/env.zsh
           └─> hyde/terminal.zsh

3. ~/.config/zsh/conf.d/hyde/terminal.zsh
   └─> Sources ~/.hyde.zshrc (if exists)
   └─> OR sources ~/.user.zsh (newer name)
   └─> Loads oh-my-zsh plugins
   └─> Loads prompt, functions, completions

4. ~/.config/zsh/.zshrc (HyDE)
   └─> Sources ~/.zshrc (YOUR CONFIG)

5. ~/.zshrc (symlinked to ../hyprdots/shell/.zshrc)
   └─> Sources ~/.zshrc.secrets
   └─> Your PATH, aliases, configs
```

**Key Insight:** Your `~/.zshrc` loads **last**, so you can override anything HyDE sets up.

See [hyde.md#architecture](./hyde.md#architecture) for the complete HyDE loading flow.

---

## Configuration Files

### File Purposes

| File | Loaded When | Purpose | Use For |
|------|-------------|---------|---------|
| `.zshenv` | Always (all shells) | Environment variables | PATH, basic exports |
| `.zprofile` | Login shells | Login-specific setup | Session initialization |
| `.zshrc` | Interactive shells | Interactive config | Aliases, functions, prompts |
| `.zlogin` | Login shells (after .zshrc) | Post-login commands | Display messages |
| `.zlogout` | Logout | Cleanup | Clear screen, logout tasks |

### This Setup's Files

| File | Managed By | Purpose | Edit? |
|------|------------|---------|-------|
| `~/.zshenv` | HyDE | Redirects to `~/.config/zsh/` | ❌ No |
| `~/.hyde.zshrc` | **YOU** | HyDE customizations (plugins, startup) | ✅ Yes |
| `~/.zshrc` | **YOU** | Main shell config (PATH, aliases) | ✅ Yes |
| `~/.zshrc.secrets` | **YOU** | API keys, tokens | ✅ Yes |
| `~/.config/zsh/*` | HyDE | Core zsh setup | ❌ No |

See [shell/README.md](../shell/README.md) for setup instructions.

---

## Environment Variables

### What are Environment Variables?

Environment variables are key-value pairs available to all programs launched from the shell.

### Common Variables

```bash
# ~/.zshrc

# Set default editor
export EDITOR=code
export VISUAL=code

# Set default pager
export PAGER=less

# Set language/locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Set XDG base directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
```

### PATH Management

The `PATH` variable determines where the shell looks for commands.

**Order matters:** Earlier entries have priority.

```bash
# ~/.zshrc

# Add directory to PATH (prepend - highest priority)
export PATH="$HOME/.local/bin:$PATH"

# Add directory to PATH (append - lowest priority)
export PATH="$PATH:$HOME/scripts"

# Multiple additions
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
```

**Common PATH additions:**

```bash
# ~/.zshrc

# Rust/Cargo
export PATH="$HOME/.cargo/bin:$PATH"

# Go
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/go/bin"

# Node/npm global packages
export PATH="$PATH:$HOME/.npm-global/bin"

# Python pip user packages
export PATH="$PATH:$HOME/.local/bin"

# Custom scripts
export PATH="$PATH:$HOME/bin"
export PATH="$PATH:$HOME/scripts"
```

### Development Tool Variables

#### Android Development

```bash
# ~/.zshrc

export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_AVD_HOME="$HOME/.config/.android/avd"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
```

#### Java

```bash
# ~/.zshrc

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH="$JAVA_HOME/bin:$PATH"
```

#### Flutter & Dart

```bash
# ~/.zshrc

export PATH="/opt/flutter/bin:$PATH"
export PATH="$PATH:/opt/flutter/bin/cache/dart-sdk/bin"
```

#### Node.js (NVM)

```bash
# ~/.zshrc

# Load NVM
source /usr/share/nvm/init-nvm.sh

# Or lazy-load for faster startup
lazy_load_nvm() {
    unset -f node npm nvm
    source /usr/share/nvm/init-nvm.sh
}
alias node='lazy_load_nvm; node'
alias npm='lazy_load_nvm; npm'
```

### SSH Configuration

```bash
# ~/.zshrc

# Use systemd user service for SSH agent
export SSH_AUTH_SOCK=/run/user/1000/ssh-agent.socket

# Or use ssh-agent directly
# eval "$(ssh-agent -s)"
```

### Secret Management

**Never put secrets directly in versioned configs!**

Use a separate secrets file:

```bash
# ~/.zshrc

# Source secrets file if it exists
[ -f ~/.zshrc.secrets ] && source ~/.zshrc.secrets
```

```bash
# ~/.zshrc.secrets (NEVER VERSION THIS FILE)

export OPENAI_API_KEY=sk-proj-...
export GITHUB_TOKEN=ghp_...
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
```

See [shell/README.md#secret-management](../shell/README.md#secret-management) for details.

---

## Aliases

### What are Aliases?

Aliases are shortcuts for commands. They make long or frequently-used commands easier to type.

### Basic Syntax

```bash
alias name='command'
alias name='command with arguments'
```

### Navigation Aliases

```bash
# ~/.zshrc

# Quick directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# Project shortcuts
alias hyprdots='cd /home/warley/life/2-areas/dev-tools/hyprdots'
alias projects='cd ~/projects'
alias dev='cd ~/dev'
```

### List Variants (using eza)

```bash
# ~/.zshrc

alias l='eza -lh --icons=auto'                                         # long list
alias ls='eza -1 --icons=auto'                                         # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -lhD --icons=auto'                                       # long list dirs
alias lt='eza --icons=auto --tree'                                     # tree view
alias lta='eza -a --icons=auto --tree'                                 # tree view with hidden
```

### System Aliases

```bash
# ~/.zshrc

# System shortcuts
alias c='clear'
alias h='history'
alias j='jobs -l'

# Safer file operations (confirm before overwrite)
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Always create parent directories
alias mkdir='mkdir -p'

# Human-readable sizes
alias df='df -h'
alias du='du -h'
alias free='free -h'
```

### Package Management (Arch/HyDE)

```bash
# ~/.zshrc

# Using HyDE's package manager wrapper
alias in='hyde-shell pm install'
alias un='hyde-shell pm remove'
alias up='hyde-shell pm upgrade'
alias pl='hyde-shell pm search installed'
alias pa='hyde-shell pm search all'

# Or using yay/paru directly
alias update='yay -Syu'
alias install='yay -S'
alias remove='yay -Rns'
alias search='yay -Ss'
alias clean='yay -Sc'
```

### Git Aliases

```bash
# ~/.zshrc

alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'
```

### Editor Aliases

```bash
# ~/.zshrc

alias v='nvim'
alias vim='nvim'
alias vi='nvim'
alias code='code .'  # Open current dir in VS Code
```

### Docker Aliases

```bash
# ~/.zshrc

alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dlog='docker logs -f'
alias dexec='docker exec -it'
```

### Override HyDE Aliases

If HyDE sets an alias you don't like, override it in `~/.zshrc` (loads last):

```bash
# ~/.zshrc

# HyDE sets: alias c='clear'
# Override to also display a message
alias c='clear && echo "Terminal cleared at $(date)"'
```

---

## Functions

### What are Functions?

Functions are reusable code blocks, more powerful than aliases.

### Basic Syntax

```bash
function_name() {
    # commands
    # $1, $2, etc. are arguments
}
```

### Useful Functions

#### Create and Enter Directory

```bash
# ~/.zshrc

mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Usage: mkcd new-project
```

#### Extract Archives

```bash
# ~/.zshrc

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"    ;;
            *.tar.gz)    tar xzf "$1"    ;;
            *.bz2)       bunzip2 "$1"    ;;
            *.rar)       unrar x "$1"    ;;
            *.gz)        gunzip "$1"     ;;
            *.tar)       tar xf "$1"     ;;
            *.tbz2)      tar xjf "$1"    ;;
            *.tgz)       tar xzf "$1"    ;;
            *.zip)       unzip "$1"      ;;
            *.Z)         uncompress "$1" ;;
            *.7z)        7z x "$1"       ;;
            *)           echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Usage: extract archive.tar.gz
```

#### Find and Kill Process

```bash
# ~/.zshrc

killport() {
    local port="$1"
    if [ -z "$port" ]; then
        echo "Usage: killport <port>"
        return 1
    fi
    local pid=$(lsof -ti:$port)
    if [ -z "$pid" ]; then
        echo "No process found on port $port"
        return 1
    fi
    echo "Killing process $pid on port $port"
    kill -9 $pid
}

# Usage: killport 3000
```

#### Git Branch Cleanup

```bash
# ~/.zshrc

git-cleanup() {
    # Delete local branches that have been merged
    git branch --merged | grep -v "\*" | grep -v "main" | grep -v "master" | xargs -n 1 git branch -d
}
```

#### Quick Backup

```bash
# ~/.zshrc

backup() {
    local file="$1"
    local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"
    cp -r "$file" "$backup"
    echo "Backed up: $backup"
}

# Usage: backup important-file.txt
```

---

## Keybindings

### Vi Mode

Enable vi-style keybindings in zsh:

```bash
# ~/.zshrc

# Enable vi mode
bindkey -v

# Reduce ESC delay
export KEYTIMEOUT=1
```

### Emacs Mode (Default)

```bash
# ~/.zshrc

# Enable emacs mode (default)
bindkey -e
```

### Custom Keybindings

```bash
# ~/.zshrc

# Ctrl-R for reverse search (even in vi mode)
bindkey '^R' history-incremental-search-backward

# Ctrl-S for forward search
bindkey '^S' history-incremental-search-forward

# Ctrl-P / Ctrl-N for history navigation
bindkey '^P' up-line-or-history
bindkey '^N' down-line-or-history

# Home / End keys
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line

# Delete key
bindkey '\e[3~' delete-char

# Ctrl-Left / Ctrl-Right for word navigation
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
```

---

## History Configuration

### Basic Settings

```bash
# ~/.zshrc (or managed by HyDE in ~/.config/zsh/conf.d/00-hyde.zsh)

# History file location
HISTFILE=~/.config/zsh/.zsh_history

# Number of commands to keep in memory
HISTSIZE=10000

# Number of commands to save to file
SAVEHIST=10000
```

### History Options

```bash
# ~/.zshrc

# Append to history file, don't overwrite
setopt APPEND_HISTORY

# Write to history file immediately, not on exit
setopt INC_APPEND_HISTORY

# Share history between sessions
setopt SHARE_HISTORY

# Don't record duplicate commands
setopt HIST_IGNORE_DUPS

# Don't record commands starting with space
setopt HIST_IGNORE_SPACE

# Remove extra blanks from commands
setopt HIST_REDUCE_BLANKS

# Don't execute immediately on history expansion
setopt HIST_VERIFY
```

### History Search

```bash
# Search history with arrow keys
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
```

---

## Best Practices

### 1. Organize Your Config

Use clear sections with comments:

```bash
# ~/.zshrc

# ============================================================================
# Secrets
# ============================================================================
[ -f ~/.zshrc.secrets ] && source ~/.zshrc.secrets

# ============================================================================
# Environment Variables
# ============================================================================
export EDITOR=nvim
export PATH="$HOME/.local/bin:$PATH"

# ============================================================================
# Development Tools
# ============================================================================
source /usr/share/nvm/init-nvm.sh
export ANDROID_HOME="$HOME/Android/Sdk"

# ============================================================================
# Aliases
# ============================================================================
alias hyprdots='cd ~/hyprdots'

# ============================================================================
# Functions
# ============================================================================
mkcd() { mkdir -p "$1" && cd "$1"; }
```

### 2. Version Your Configs

Keep your configs in a git repository:

```bash
# Setup (already done in this project)
~/hyprdots/shell/
├── .zshrc
├── .hyde.zshrc
└── README.md

# Symlink to home
ln -s ~/hyprdots/shell/.zshrc ~/.zshrc
ln -s ~/hyprdots/shell/.hyde.zshrc ~/.hyde.zshrc
```

See [shell/README.md](../shell/README.md) for complete setup.

### 3. Keep Secrets Separate

**Never commit secrets to git!**

```bash
# ~/.zshrc
[ -f ~/.zshrc.secrets ] && source ~/.zshrc.secrets

# ~/.zshrc.secrets (add to .gitignore)
export OPENAI_API_KEY=sk-proj-...

# Set restrictive permissions
chmod 600 ~/.zshrc.secrets
```

### 4. Test Changes Before Committing

```bash
# Test your changes
source ~/.zshrc

# Verify environment
echo $PATH
alias
env | grep -i custom_var

# If good, commit
cd ~/hyprdots
git add shell/.zshrc
git commit -m "feat(shell): add custom aliases"
```

### 5. Document Your Customizations

Add comments explaining why you added something:

```bash
# ~/.zshrc

# Lazy-load NVM to reduce shell startup time from 2s to 0.2s
lazy_load_nvm() {
    unset -f node npm nvm
    source /usr/share/nvm/init-nvm.sh
}
alias node='lazy_load_nvm; node'
```

### 6. Use Functions for Complex Logic

If an alias needs logic, use a function:

```bash
# Bad - alias with complex logic
alias gitpush='git add . && git commit -m "$(date)" && git push'

# Good - function with error handling
gitpush() {
    local message="${1:-Update $(date +%Y-%m-%d)}"
    git add . &&
    git commit -m "$message" &&
    git push
}
```

### 7. Reload Efficiently

```bash
# Reload zsh config
source ~/.zshrc

# Or create an alias
alias reload='source ~/.zshrc'

# Or create a function that clears first
reload() {
    clear
    source ~/.zshrc
    echo "Config reloaded successfully"
}
```

---

## Troubleshooting

### Command Not Found

**Problem:** Custom commands not working

**Check:**
1. Is the command in PATH?
   ```bash
   echo $PATH
   which command-name
   ```

2. Is the directory added correctly?
   ```bash
   # Wrong - missing colon
   export PATH="$HOME/bin$PATH"

   # Correct
   export PATH="$HOME/bin:$PATH"
   ```

### Alias Not Working

**Problem:** Alias not expanding

**Solutions:**
```bash
# 1. Check if alias exists
alias alias-name

# 2. Reload config
source ~/.zshrc

# 3. Check for typos (quotes, spacing)
# Wrong
alias ls = 'eza'  # spaces around =
alias ls=eza      # missing quotes

# Correct
alias ls='eza'
```

### Environment Variable Not Set

**Problem:** Variable not available in programs

**Solutions:**
```bash
# 1. Use export, not just assignment
VAR=value        # Only in shell
export VAR=value # Available to child processes

# 2. Source the config
source ~/.zshrc

# 3. Check where it's defined
grep -r "VAR_NAME" ~/.zshrc ~/.zshrc.secrets
```

### Slow Shell Startup

**Problem:** Terminal takes long to open

**Solutions:**

1. **Profile startup time:**
   ```bash
   # Add to top of ~/.zshrc
   zmodload zsh/zprof

   # Add to bottom of ~/.zshrc
   zprof
   ```

2. **Lazy-load expensive tools:**
   ```bash
   # Instead of loading immediately
   # source /usr/share/nvm/init-nvm.sh

   # Lazy-load on first use
   lazy_load_nvm() {
       unset -f node npm nvm
       source /usr/share/nvm/init-nvm.sh
   }
   alias node='lazy_load_nvm; node'
   ```

3. **Reduce compinit checks:**
   ```bash
   # ~/.hyde.zshrc
   HYDE_ZSH_COMPINIT_CHECK=24  # Check once per day instead of hourly
   ```

### Config Not Taking Effect

**Problem:** Changes in ~/.zshrc not working

**Check loading order:**
```bash
# Is ~/.zshrc being sourced?
grep "source ~/.zshrc" ~/.config/zsh/.zshrc

# Is HyDE overriding your settings?
# Move your config AFTER the source line in ~/.zshrc
# Or override HyDE settings (yours loads last)
```

---

## Advanced Topics

### Zsh Options

Enable powerful zsh features:

```bash
# ~/.zshrc

# Auto-cd when typing directory name
setopt AUTO_CD

# Correct command typos
setopt CORRECT

# Glob dotfiles without typing dot
setopt GLOB_DOTS

# Use extended globbing (^, ~, #)
setopt EXTENDED_GLOB

# Don't beep on errors
setopt NO_BEEP

# Make cd push old directory onto stack
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
```

### Completions

Custom completions:

```bash
# ~/.zshrc

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Menu selection
zstyle ':completion:*' menu select

# Colors in completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Group completions
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%B%d%b'
```

### Hooks

Run commands at specific events:

```bash
# ~/.zshrc

# Run before each command
autoload -Uz add-zsh-hook

precmd() {
    # Runs before prompt is displayed
    echo "Command finished at $(date +%H:%M:%S)"
}

preexec() {
    # Runs before command executes
    # $1 = command as typed
    # $2 = command as will be executed
    echo "Running: $2"
}
```

---

## References

- **Zsh Documentation:** [zsh.sourceforge.io/Doc/](https://zsh.sourceforge.io/Doc/)
- **Zsh Guide:** [zsh.sourceforge.io/Guide/](https://zsh.sourceforge.io/Guide/)
- **oh-my-zsh:** [ohmyz.sh](https://ohmyz.sh/)
- **Related Docs:**
  - [HyDE Configuration Guide](./hyde.md)
  - [Shell Directory Setup](../shell/README.md)
