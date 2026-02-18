# Edit Your Production Code from Telegram with OpenCode and DigitalOcean Gradient

If you've been exploring OpenClaw but feel like it's a bit much for what you actually need — and all you really want is the ability to update or fix your code from Telegram — there's a much simpler option.

[OpenCode](https://opencode.ai) is an open-source, terminal-first AI coding agent that supports 75+ LLM providers. Pair it with [OpenCode Telegram Mirror](https://github.com/ajoslin/opencode-telegram-mirror) and you get a clean Telegram interface to your coding agent.

It does one thing well: it lets you send messages over Telegram to OpenCode running on your server.

No multi-agent orchestration.
No dashboard.
No exposed control plane.

Just you → Telegram → your Droplet → your code.

<table><tr>
<td><img width="300" alt="Telegram bot conversation" src="https://github.com/user-attachments/assets/ca2c91d9-473b-44c5-8996-ff8bf04237c1" /></td>
<td><img width="300" alt="Telegram bot conversation" src="https://github.com/user-attachments/assets/8b8ac8e9-5dd4-4dc9-b032-3527c9e31a4e" /></td>
</tr></table>

In this guide we'll use [DigitalOcean Gradient](https://docs.digitalocean.com/products/gradient-ai-platform/) as the LLM provider — it offers an OpenAI-compatible API with access to models from Anthropic, Meta, OpenAI, and others, all billed per token with no subscriptions.

If that's what you're after, here's how to set it up.

------

# First: Create an OpenCode Droplet

DigitalOcean offers an [OpenCode 1-Click App](https://marketplace.digitalocean.com/apps/opencode) on their Marketplace. It gives you an Ubuntu 24.04 Droplet with OpenCode and Node.js pre-installed — no manual installation needed.

1. Go to the [OpenCode Marketplace page](https://marketplace.digitalocean.com/apps/opencode)
2. Click **Create OpenCode Droplet**
3. Pick a basic plan (the smallest size works for experimenting)
4. Choose your region
5. Add your SSH key (recommended)
6. Click **Create Droplet**

Or use this direct link:

👉 https://cloud.digitalocean.com/droplets/new?onboarding_origin=marketplace&appId=217594412&image=opencode

Once your Droplet is ready, SSH into it:

```bash
ssh root@your_droplet_ip
```

Now we'll configure it.

------

# Droplet Setup

Your OpenCode Droplet already has OpenCode and Node.js installed. The steps below configure GitHub access, the LLM provider, and the Telegram mirror.

## 1. Install Additional Packages

The 1-Click image has most things you need. We just need to add `zsh` and the GitHub CLI:

```bash
sudo apt update
sudo apt install -y zsh gh
```

------

## 2. Install Oh My Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

------

## 3. Generate an SSH Deploy Key

```bash
ssh-keygen -t ed25519 -C "do-droplet-deploy-key" -f ~/.ssh/github_deploy_key
```

------

## 4. Add the Public Key to GitHub

Print it:

```bash
cat ~/.ssh/github_deploy_key.pub
```

Add it under:

GitHub → Settings → SSH and GPG keys → New SSH key
Key type: **Authentication**

------

## 5. Configure SSH to Use the Key

```bash
cat >> ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_deploy_key
  IdentitiesOnly yes
EOF
```

------

## 6. Lock Down SSH Config Permissions

```bash
chmod 600 ~/.ssh/config
```

------

## 7. Pre-Register GitHub's Host Identity

```bash
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
chmod 644 ~/.ssh/known_hosts
```

------

## 8. Authenticate GitHub CLI

```bash
gh auth login
```

This is separate from SSH keys.

Follow the prompts:

1. Select **GitHub.com**
2. Select **HTTPS**
3. Say **Y** to authenticate Git with GitHub credentials
4. Choose **Paste an authentication token**

Generate a token locally at:

https://github.com/settings/tokens

Use:

- `repo`
- `read:org`

Then verify:

```bash
gh auth status
```

------

## 9. (Optional) Fix Terminal for Ghostty Users

If you're SSHing in with Ghostty and see terminal issues:

```bash
echo 'export TERM=xterm-256color' >> ~/.zshrc
source ~/.zshrc
```

------

## 10. Set Your DigitalOcean Gradient Model Access Key

Create a model access key in the DigitalOcean control panel:

👉 https://cloud.digitalocean.com/gen-ai/model-access-keys

Then add it to your shell:

```bash
nano ~/.zshrc
```

Add:

```bash
export MODEL_ACCESS_KEY="your-key-here"
```

Reload:

```bash
source ~/.zshrc
```

------

## 11. Configure OpenCode to Use DigitalOcean Gradient

Create the OpenCode config directory and config file:

```bash
mkdir -p ~/.config/opencode
cat > ~/.config/opencode/opencode.json <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "do-gradient": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "DigitalOcean Gradient",
      "options": {
        "baseURL": "https://inference.do-ai.run/v1"
      },
      "models": {
        "anthropic-claude-sonnet-4.5": {
          "name": "Claude Sonnet 4.5 (via Gradient)"
        }
      }
    }
  },
  "model": "do-gradient/anthropic-claude-sonnet-4.5"
}
EOF
```

This tells OpenCode to use DigitalOcean Gradient's serverless inference endpoint as an OpenAI-compatible provider, with `anthropic-claude-sonnet-4.5` as the default model.

Next, store the API key for OpenCode:

```bash
mkdir -p ~/.local/share/opencode
cat > ~/.local/share/opencode/auth.json <<EOF
{
  "do-gradient": {
    "type": "api",
    "key": "$MODEL_ACCESS_KEY"
  }
}
EOF
chmod 600 ~/.local/share/opencode/auth.json
```

------

## 12. Clone OpenCode Telegram Mirror

```bash
git clone git@github.com:ajoslin/opencode-telegram-mirror.git
cd opencode-telegram-mirror
```

Use the SSH URL (`git@github.com:`), not HTTPS.

------

## 13. Install Dependencies

```bash
npm install
```

------

## 14. Create a Telegram Bot

In Telegram:

1. Message **@BotFather**
2. Run `/newbot`
3. Choose a name (must end with `bot`)
4. Save the token

------

## 15. Configure the Bot

```bash
mkdir -p /root/projects
nano .env
```

Fill in:

```
TELEGRAM_BOT_TOKEN=<your token>
TELEGRAM_CHAT_ID=<your chat ID>
```

To get your Telegram chat ID, message **@userinfobot**.

------

## 16. Run the Bot

```bash
npx opencode-telegram-mirror /root/projects
```

That's it.

Now you can send messages like:

> Let's remove the about link from the header nav on the rootein GitHub repo

OpenCode runs locally on your Droplet, reads your repo, makes changes, and responds in Telegram — powered by DigitalOcean Gradient.

No heavy framework.
No exposed agent.
Just a tight loop between you and your server.

If OpenClaw feels like overkill and you just want something simple you can understand and control, this is a very practical middle ground.
