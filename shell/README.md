# Shell Configuration

This directory contains versioned shell configuration files for zsh.

## Structure

```
shell/
├── .zshrc           # Main zsh configuration (versioned)
├── .hyde.zshrc      # HyDE-specific overrides (versioned)
└── README.md        # This file
```

## Setup

These files are designed to be symlinked to your home directory:

```bash
# Backup existing files (if not already done)
mv ~/.zshrc ~/.zshrc.backup
mv ~/.hyde.zshrc ~/.hyde.zshrc.backup

# Create symlinks
ln -s /home/warley/life/2-areas/dev-tools/hyprdots/shell/.zshrc ~/.zshrc
ln -s /home/warley/life/2-areas/dev-tools/hyprdots/shell/.hyde.zshrc ~/.hyde.zshrc

# Reload shell configuration
source ~/.zshrc
```

## Secret Management

**IMPORTANT**: API keys, tokens, and other secrets are stored in `~/.zshrc.secrets`, which is **NOT** versioned.

### Creating the Secrets File

Create `~/.zshrc.secrets` with your sensitive data:

```bash
# ~/.zshrc.secrets
# IMPORTANT: This file is NOT versioned. Keep it secure.

export OPENAI_API_KEY=your-key-here
export GITHUB_TOKEN_EDGE=your-token-here
# Add other secrets below
```

### Security Best Practices

1. **File permissions**: Restrict access to secrets file
   ```bash
   chmod 600 ~/.zshrc.secrets
   ```

2. **Global gitignore**: Prevent accidental commits
   ```bash
   echo "*.secrets" >> ~/.config/git/ignore
   ```

3. **Never commit**: The `.zshrc.secrets` file should never be committed to any repository

4. **Backup carefully**: If backing up your home directory, ensure secrets are excluded or encrypted

### How It Works

The main `.zshrc` file sources the secrets file with this line:

```bash
[ -f ~/.zshrc.secrets ] && source ~/.zshrc.secrets
```

This means:
- If `~/.zshrc.secrets` exists, it will be sourced and all exports will be available
- If the file doesn't exist, the shell will continue without errors
- Secrets are loaded before any other configuration that might need them

## Adding New Secrets

To add a new secret:

1. Edit `~/.zshrc.secrets` (not the versioned `.zshrc`)
2. Add your export statement: `export SECRET_NAME=secret-value`
3. Reload the shell: `source ~/.zshrc`
4. Verify: `echo $SECRET_NAME`

## Aliases

The following aliases are configured in `.zshrc`:

- `hyprdots` - Quick navigation to the hyprdots repository

## Modifying Configuration

Since these files are symlinked:
- Any edits to `~/.zshrc` will modify the versioned file in this repository
- You can commit and track changes to your shell configuration
- Changes are immediately active after sourcing: `source ~/.zshrc`

## HyDE Integration

The `.hyde.zshrc` file contains HyDE-specific configurations:
- Startup commands (fastfetch, pokego, etc.)
- HyDE-specific aliases
- oh-my-zsh plugins

You can customize this file while keeping HyDE's structure intact.
