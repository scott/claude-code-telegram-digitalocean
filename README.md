# Claude Code Telegram on DigitalOcean

Automated setup script for running [Claude Code Telegram](https://github.com/RichardAtCT/claude-code-telegram) on a DigitalOcean Droplet.

Send messages to Claude Code from Telegram. It reads your repo, makes changes, and responds — all running on your Droplet.

## Quick Start

SSH into a fresh Ubuntu Droplet and run:

```bash
curl -fsSL https://raw.githubusercontent.com/ajot/claude-code-telegram-digitalocean/main/setup-droplet.sh -o setup-droplet.sh
bash setup-droplet.sh
```

The script will prompt you for everything it needs along the way.

## What It Sets Up

- System packages (zsh, git, gh, python3, build tools)
- Oh My Zsh (default shell)
- SSH deploy key for GitHub
- GitHub CLI authentication
- Poetry (Python package manager)
- Claude Code CLI
- Bot repo cloned and dependencies installed
- `.env` configured with your Telegram bot token and settings

## Prerequisites

Before running the script, have these ready:

- A [DigitalOcean Droplet](https://docs.digitalocean.com/products/droplets/how-to/create/) running Ubuntu
- A [GitHub personal access token](https://github.com/settings/tokens) (scopes: `repo`, `read:org`)
- An [Anthropic API key](https://console.anthropic.com/)
- A Telegram bot token from [@BotFather](https://t.me/BotFather)
- Your Telegram user ID from [@userinfobot](https://t.me/userinfobot)

## Detailed Walkthrough

See [docs/blog-droplet-setup.md](docs/blog-droplet-setup.md) for a step-by-step explanation of every command the script runs.
