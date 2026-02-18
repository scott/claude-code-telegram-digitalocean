# Edit Your Production Code from Telegram (Without Running OpenClaw)

If you’ve been exploring OpenClaw but feel like it’s a bit much for what you actually need — and all you really want is the ability to update or fix your code from Telegram — there’s a much simpler option.

[Levelsio](https://x.com/levelsio/status/2023960543959101938?s=20) recently pointed to an open source project called [Claude Code Telegram](https://github.com/RichardAtCT/claude-code-telegram).

It does one thing well: it lets you send messages over Telegram to Claude Code running on your server.

No multi-agent orchestration.
No dashboard.
No exposed control plane.

Just you → Telegram → your Droplet → your code.

If that’s what you’re after, here’s how to set it up on a DigitalOcean Droplet.

------

# First: Create a DigitalOcean Droplet

If you don’t already have a server, you’ll need a basic Ubuntu Droplet.

In the DigitalOcean control panel:

1. Click **Create → Droplets**
2. Choose **Ubuntu** (latest LTS version is fine)
3. Pick a basic plan (the smallest size works for experimenting)
4. Choose your region
5. Add your SSH key (recommended)
6. Click **Create Droplet**

If you need a detailed walkthrough, DigitalOcean has a guide here:

👉 https://docs.digitalocean.com/products/droplets/how-to/create/

Once your Droplet is ready, SSH into it:

```bash
ssh root@your_droplet_ip
```

Now we’ll set it up.

------

# Droplet Setup

## 1. Update Package Lists

```bash
sudo apt update
```

------

## 2. Install Zsh

```bash
sudo apt install zsh -y
```

------

## 3. Install Essential Build Tools

```bash
sudo apt install build-essential procps curl file git -y
```

This installs compilers, process utilities, curl, file detection, and git.

------

## 4. Install GitHub CLI

```bash
sudo apt install gh
```

------

## 4b. Authenticate GitHub CLI

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

## 5. Install Oh My Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

------

## 6. Install Python Dependencies

```bash
sudo apt install -y curl python3-venv python3-pip
```

------

## 7. Generate an SSH Deploy Key

```bash
ssh-keygen -t ed25519 -C "do-droplet-deploy-key" -f ~/.ssh/github_deploy_key
```

------

## 8. Add the Public Key to GitHub

Print it:

```bash
cat ~/.ssh/github_deploy_key.pub
```

Add it under:

GitHub → Settings → SSH and GPG keys → New SSH key
Key type: **Authentication**

------

## 9. Configure SSH to Use the Key

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

## 10. Lock Down SSH Config Permissions

```bash
chmod 600 ~/.ssh/config
```

------

## 11. Pre-Register GitHub’s Host Identity

```bash
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
```

------

## 12. Set known_hosts Permissions

```bash
chmod 644 ~/.ssh/known_hosts
```

------

## 13. Install Poetry

```bash
curl -sSL https://install.python-poetry.org | python3 -
```

------

## 14. Add Poetry to Your PATH

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

------

## 15. Verify Poetry Installation

```bash
poetry --version
```

------

## 16. Install Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

------

## 16b. (Optional) Fix Terminal for Ghostty Users

If you’re SSHing in with Ghostty and see terminal issues:

```bash
echo 'export TERM=xterm-256color' >> ~/.zshrc
source ~/.zshrc
```

------

## 17. Set Your Anthropic API Key

```bash
nano ~/.zshrc
```

Add:

```bash
export ANTHROPIC_API_KEY="sk-..."
```

Reload:

```bash
source ~/.zshrc
```

------

## 18. Clone Claude Code Telegram

```bash
git clone git@github.com:RichardAtCT/claude-code-telegram.git
cd claude-code-telegram
```

Use the SSH URL (`git@github.com:`), not HTTPS.

------

## 19. Install Bot Dependencies

```bash
make dev
```

If you see:

```
Command not found: pre-commit
pre-commit not configured yet
```

That’s normal and safe to ignore.

------

## 20. Create a Telegram Bot

In Telegram:

1. Message **@BotFather**
2. Run `/newbot`
3. Choose a name (must end with `bot`)
4. Save the token

------

## 21. Configure the Bot

```bash
mkdir /root/projects
cp .env.example .env
nano .env
```

Fill in:

```
TELEGRAM_BOT_TOKEN=<your token>
TELEGRAM_BOT_USERNAME=<your bot username>
APPROVED_DIRECTORY=/root/projects
ALLOWED_USERS=<your Telegram user ID>
USE_SDK=true
```

To get your Telegram user ID, message **@userinfobot**.

The `ALLOWED_USERS` setting is important — the bot ignores everyone else.

------

## 22. Run the Bot

For first run:

```bash
make run-debug
```

For normal mode:

```bash
make run
```

That’s it.

Now you can send messages like:

> Fix the database lock issue
> Add parks to the map by default
> Update that broken route

Claude Code runs locally on your Droplet, reads your repo, makes changes, and responds in Telegram.

No heavy framework.
No exposed agent.
Just a tight loop between you and your server.

If OpenClaw feels like overkill and you just want something simple you can understand and control, this is a very practical middle ground.
