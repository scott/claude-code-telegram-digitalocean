# OpenCode Telegram on DigitalOcean

Automated setup script for running [OpenCode Telegram Mirror](https://github.com/ajoslin/opencode-telegram-mirror) on a DigitalOcean Droplet, powered by [DigitalOcean Gradient](https://docs.digitalocean.com/products/gradient-ai-platform/).

Send messages to OpenCode from Telegram. It reads your repo, makes changes, and responds — all running on your Droplet.

<table><tr>
<td><img width="300" alt="Telegram bot conversation" src="https://github.com/user-attachments/assets/ca2c91d9-473b-44c5-8996-ff8bf04237c1" /></td>
<td><img width="300" alt="Telegram bot conversation" src="https://github.com/user-attachments/assets/8b8ac8e9-5dd4-4dc9-b032-3527c9e31a4e" /></td>
</tr></table>

## Quick Start

1. **Create an OpenCode Droplet** from the [DigitalOcean Marketplace](https://marketplace.digitalocean.com/apps/opencode) — this gives you OpenCode and Node.js pre-installed.

   [![Create OpenCode Droplet](https://img.shields.io/badge/DigitalOcean-Create_OpenCode_Droplet-0080FF?style=for-the-badge&logo=digitalocean)](https://cloud.digitalocean.com/droplets/new?onboarding_origin=marketplace&appId=217594412&image=opencode)

2. **SSH in** and run the setup script:

```bash
curl -fsSL https://raw.githubusercontent.com/ajot/claude-code-telegram-digitalocean/main/setup-droplet.sh -o setup-droplet.sh
bash setup-droplet.sh
```

The script will prompt you for everything it needs along the way.

## What It Sets Up

The 1-Click image provides OpenCode and Node.js. The setup script configures everything else:

- Oh My Zsh (default shell)
- SSH deploy key for GitHub
- GitHub CLI authentication
- OpenCode configured with DigitalOcean Gradient as the LLM provider
- Telegram mirror repo cloned and dependencies installed
- `.env` configured with your Telegram bot token and chat ID

## Prerequisites

Before running the script, have these ready:

- An [OpenCode Droplet](https://marketplace.digitalocean.com/apps/opencode) (1-Click App from the DigitalOcean Marketplace)
- A [GitHub personal access token](https://github.com/settings/tokens) (scopes: `repo`, `read:org`)
- A [DigitalOcean Gradient model access key](https://cloud.digitalocean.com/gen-ai/model-access-keys)
- A Telegram bot token from [@BotFather](https://t.me/BotFather)
- Your Telegram chat ID from [@userinfobot](https://t.me/userinfobot)

## Detailed Walkthrough

See [blog-droplet-setup.md](blog-droplet-setup.md) for a step-by-step explanation of every command the script runs.
