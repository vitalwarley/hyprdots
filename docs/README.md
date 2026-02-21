# Documentation Index

Comprehensive documentation for the hyprdots configuration repository.

---

## Available Guides

### Shell Configuration

#### [Zsh Configuration Guide](./zsh.md)
Complete reference for zsh shell configuration.

**Topics covered:**
- File loading order and precedence
- Environment variables and PATH management
- Aliases and functions
- Keybindings (vi mode, emacs mode)
- History configuration
- Best practices for versioned configs
- Troubleshooting common issues

**Use this guide when:**
- Setting up new development tools (Node, Python, Java, etc.)
- Creating custom aliases or functions
- Understanding how your shell loads configurations
- Debugging PATH or environment issues

---

#### [HyDE Configuration Guide](./hyde.md)
Understanding HyDE desktop environment integration.

**Topics covered:**
- HyDE architecture and design philosophy
- Directory structure and file purposes
- User customization points
- oh-my-zsh plugin management
- Update safety and version control
- Overriding HyDE defaults

**Use this guide when:**
- Customizing HyDE behavior (prompts, plugins, startup)
- Understanding which files are safe to edit
- Debugging conflicts between HyDE and user configs
- Planning HyDE updates without breaking customizations

---

### Setup Guides

#### [Shell Directory Setup](../shell/README.md)
Quick reference for setting up shell configurations.

**Topics covered:**
- Symlink creation
- Secret management with `~/.zshrc.secrets`
- Security best practices
- Quick setup instructions

**Use this guide when:**
- Setting up on a new machine
- Creating the initial configuration
- Managing API keys and tokens

---

## Quick Links

### Common Tasks

| Task | Guide | Section |
|------|-------|---------|
| Add environment variable | [zsh.md](./zsh.md#environment-variables) | Environment Variables |
| Create custom alias | [zsh.md](./zsh.md#aliases) | Aliases |
| Override HyDE plugin | [hyde.md](./hyde.md#oh-my-zsh-plugins) | Customization Points |
| Manage API keys | [shell/README.md](../shell/README.md#secret-management) | Secret Management |
| Fix slow startup | [zsh.md](./zsh.md#slow-shell-startup) | Troubleshooting |
| Customize HyDE prompt | [hyde.md](./hyde.md#custom-prompt-framework) | Advanced Configuration |

### Configuration Files

| File | Purpose | Documentation |
|------|---------|---------------|
| `~/.zshrc` | Main shell config | [zsh.md](./zsh.md#configuration-files) |
| `~/.hyde.zshrc` | HyDE customizations | [hyde.md](./hyde.md#configuration-files) |
| `~/.zshrc.secrets` | API keys, tokens | [shell/README.md](../shell/README.md#secret-management) |
| `~/.config/zsh/` | HyDE core files | [hyde.md](./hyde.md#directory-structure) |

---

## Documentation Structure

```
docs/
├── README.md           # This file - documentation index
├── zsh.md              # Complete zsh configuration reference
└── hyde.md             # HyDE integration and architecture

shell/
└── README.md           # Quick setup guide for shell configs
```

---

## Contributing to Documentation

When adding new documentation:

1. **Follow the structure:**
   - Overview section with key concepts
   - Table of contents for long documents
   - Code examples with clear comments
   - Cross-references to related docs

2. **Use mermaid diagrams** for complex flows:
   ```markdown
   ```mermaid
   graph TB
       A[Start] --> B[Process]
       B --> C[End]
   ```
   ```

3. **Add cross-links** using relative paths:
   ```markdown
   See [zsh.md](./zsh.md#section) for details.
   ```

4. **Update this index** when adding new guides

---

## External Resources

### Zsh
- [Official Zsh Documentation](https://zsh.sourceforge.io/Doc/)
- [Zsh User's Guide](https://zsh.sourceforge.io/Guide/)
- [oh-my-zsh](https://ohmyz.sh/)

### HyDE
- [HyDE GitHub Repository](https://github.com/prasanthrangan/hyprdots)
- [Hyprland Documentation](https://hyprland.org/)

### Shell Best Practices
- [Bash Guide for Beginners](https://tldp.org/LDP/Bash-Beginners-Guide/html/)
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
