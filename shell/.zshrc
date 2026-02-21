# User ZSH Configuration (Versioned)
# This file is symlinked to ~/.zshrc and versioned in the hyprdots repository.
#
# For HyDE not to touch your beloved configurations, we use:
# 1. ~/.hyde.zshrc - for customizing shell-related HyDE configurations (also versioned)
# 2. ~/.zshenv - for updating zsh environment variables handled by HyDE
# 3. ~/.zshrc.secrets - for API keys and tokens (NOT versioned, local only)

# ============================================================================
# Secrets (sourced from separate file)
# ============================================================================
# Source secrets file if it exists (contains API keys, tokens, etc.)
[ -f ~/.zshrc.secrets ] && source ~/.zshrc.secrets

# ============================================================================
# HyDE Integration
# ============================================================================
. "$HOME/.local/share/../bin/env"

# ============================================================================
# Shell Configuration
# ============================================================================
# Vi mode keybindings
set vi
bindkey -v
bindkey '^R' history-incremental-search-backward

# ============================================================================
# Development Tools
# ============================================================================

# Rust/Cargo
export PATH="$HOME/.cargo/bin:$PATH"

# Node Version Manager (NVM)
source /usr/share/nvm/init-nvm.sh

# Android SDK
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_AVD_HOME="$HOME/.config/.android/avd"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"

# Java
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk

# Flutter & Dart
export PATH="/opt/flutter/bin:$PATH"
export PATH="$PATH:/opt/flutter/bin/cache/dart-sdk/bin"

# ============================================================================
# ============================================================================
# Aliases
# ============================================================================
alias hyprdots='cd /home/warley/life/2-areas/dev-tools/hyprdots'

# ============================================================================
# Additional Configuration
# ============================================================================
# Add your custom aliases and configurations below this line
