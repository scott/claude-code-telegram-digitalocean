#!/usr/bin/env bash
#
# setup-droplet.sh — Automated setup for OpenCode Telegram mirror on an OpenCode 1-Click Droplet
#
# Usage: bash setup-droplet.sh
#
# Prerequisites: Create an OpenCode Droplet from the DigitalOcean Marketplace:
#   https://marketplace.digitalocean.com/apps/opencode
#
# The 1-Click image comes with OpenCode and Node.js pre-installed.
# This script configures everything else: GitHub access, DigitalOcean Gradient
# as the LLM provider, and the Telegram mirror bot.
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { echo -e "\n\033[1;34m==>\033[0m \033[1m$*\033[0m"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
warn()  { echo -e "\033[1;33m  !\033[0m $*"; }
pause() { echo; read -rp "  Press Enter to continue..." ; }

# ---------------------------------------------------------------------------
# Section 1: Additional system packages
# ---------------------------------------------------------------------------

info "Section 1: Installing additional system packages"

apt update
apt install -y zsh gh

ok "System packages installed"

# ---------------------------------------------------------------------------
# Section 2: Oh My Zsh
# ---------------------------------------------------------------------------

info "Section 2: Installing Oh My Zsh and setting Zsh as default shell"

if [ -d "$HOME/.oh-my-zsh" ]; then
    warn "Oh My Zsh is already installed — skipping"
else
    # RUNZSH=no prevents the installer from launching zsh (which would halt the script)
    # CHSH=yes sets zsh as the default login shell
    RUNZSH=no CHSH=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh My Zsh installed and Zsh set as default shell"
fi

# ---------------------------------------------------------------------------
# Section 3: SSH key for GitHub
# ---------------------------------------------------------------------------

info "Section 3: Setting up SSH key for GitHub"

SSH_KEY_PATH="$HOME/.ssh/github_deploy_key"

if [ -f "$SSH_KEY_PATH" ]; then
    warn "SSH key already exists at $SSH_KEY_PATH — skipping generation"
else
    ssh-keygen -t ed25519 -C "do-droplet-deploy-key" -f "$SSH_KEY_PATH" -N ""
    ok "SSH key generated"
fi

echo
echo "  Your public key (copy this):"
echo "  -----------------------------------------------------------"
cat "${SSH_KEY_PATH}.pub"
echo "  -----------------------------------------------------------"
echo
echo "  Add this key to GitHub:"
echo "    1. Go to https://github.com/settings/ssh/new"
echo "    2. Title: \"DO Droplet Deploy Key\""
echo "    3. Key type: Authentication"
echo "    4. Paste the public key above"
echo "    5. Click \"Add SSH key\""

pause

# Write SSH config (idempotent — only if not already configured)
if ! grep -q "github_deploy_key" "$HOME/.ssh/config" 2>/dev/null; then
    cat >> "$HOME/.ssh/config" <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_deploy_key
  IdentitiesOnly yes
EOF
    ok "SSH config written"
else
    warn "SSH config for github_deploy_key already exists — skipping"
fi

chmod 600 "$HOME/.ssh/config"

ssh-keyscan -H github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
chmod 644 "$HOME/.ssh/known_hosts"

ok "GitHub SSH setup complete"

# ---------------------------------------------------------------------------
# Section 4: GitHub CLI auth
# ---------------------------------------------------------------------------

info "Section 4: Authenticating GitHub CLI"

if gh auth status &>/dev/null; then
    warn "GitHub CLI is already authenticated — skipping"
else
    echo "  You need a GitHub personal access token (classic)."
    echo "  Generate one at: https://github.com/settings/tokens"
    echo "  Required scopes: repo, read:org"
    echo
    read -rsp "  Paste your GitHub token: " GH_TOKEN
    echo

    echo "$GH_TOKEN" | gh auth login --with-token
    ok "GitHub CLI authenticated"
fi

# ---------------------------------------------------------------------------
# Section 5: DigitalOcean Gradient
# ---------------------------------------------------------------------------

info "Section 5: Configuring DigitalOcean Gradient"

echo
echo "  You need a DigitalOcean Gradient model access key."
echo "  Create one at: https://cloud.digitalocean.com/gen-ai/model-access-keys"
echo
read -rsp "  Enter your Gradient model access key: " GRADIENT_KEY
echo

# Add to zshrc if not already there
if ! grep -q 'MODEL_ACCESS_KEY' "$HOME/.zshrc" 2>/dev/null; then
    echo "export MODEL_ACCESS_KEY=\"$GRADIENT_KEY\"" >> "$HOME/.zshrc"
    ok "MODEL_ACCESS_KEY added to ~/.zshrc"
else
    warn "MODEL_ACCESS_KEY already in ~/.zshrc — skipping (update manually if needed)"
fi

export MODEL_ACCESS_KEY="$GRADIENT_KEY"

# Write OpenCode global config
mkdir -p "$HOME/.config/opencode"

cat > "$HOME/.config/opencode/opencode.json" <<'EOF'
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

ok "OpenCode config written to ~/.config/opencode/opencode.json"

# Write OpenCode auth config
mkdir -p "$HOME/.local/share/opencode"

cat > "$HOME/.local/share/opencode/auth.json" <<EOF
{
  "do-gradient": {
    "type": "api",
    "key": "$GRADIENT_KEY"
  }
}
EOF

chmod 600 "$HOME/.local/share/opencode/auth.json"

ok "OpenCode auth config written to ~/.local/share/opencode/auth.json"

# ---------------------------------------------------------------------------
# Section 6: Clone and setup Telegram mirror
# ---------------------------------------------------------------------------

info "Section 6: Cloning and setting up the Telegram mirror"

REPO_DIR="$HOME/opencode-telegram-mirror"

if [ -d "$REPO_DIR" ]; then
    warn "Repo already exists at $REPO_DIR — skipping clone"
else
    git clone git@github.com:ajoslin/opencode-telegram-mirror.git "$REPO_DIR"
    ok "Repo cloned"
fi

cd "$REPO_DIR"

info "Installing dependencies"
npm install
ok "Dependencies installed"

# ---------------------------------------------------------------------------
# Section 7: Configure environment
# ---------------------------------------------------------------------------

info "Section 7: Configuring environment"

mkdir -p /root/projects

echo
echo "  You need a Telegram bot token from @BotFather."
echo "  If you haven't created one yet, open Telegram, message @BotFather,"
echo "  send /newbot, and follow the prompts."
echo
read -rp  "  Telegram bot token: " TG_TOKEN
echo
echo "  Enter your Telegram chat ID. To find yours, message @userinfobot on Telegram."
read -rp  "  Telegram chat ID: " TG_CHAT_ID

cat > "$REPO_DIR/.env" <<EOF
TELEGRAM_BOT_TOKEN=$TG_TOKEN
TELEGRAM_CHAT_ID=$TG_CHAT_ID
EOF

ok ".env file written"

# ---------------------------------------------------------------------------
# Section 8: Optional extras
# ---------------------------------------------------------------------------

info "Section 8: Optional extras"

echo
read -rp "  Are you using Ghostty terminal? (y/N): " GHOSTTY

if [[ "$GHOSTTY" =~ ^[Yy]$ ]]; then
    if ! grep -q 'TERM=xterm-256color' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export TERM=xterm-256color' >> "$HOME/.zshrc"
        ok "Added TERM=xterm-256color to ~/.zshrc"
    else
        warn "TERM already set in ~/.zshrc — skipping"
    fi
fi

# ---------------------------------------------------------------------------
# Section 9: Done!
# ---------------------------------------------------------------------------

info "Setup complete!"

echo
echo "  What was set up:"
echo "    - Oh My Zsh (default shell)"
echo "    - SSH key for GitHub"
echo "    - GitHub CLI authenticated"
echo "    - OpenCode configured with DigitalOcean Gradient"
echo "    - Telegram mirror cloned to $REPO_DIR"
echo "    - Dependencies installed"
echo "    - .env configured"
echo
echo "  (OpenCode and Node.js were pre-installed by the 1-Click image)"
echo
echo "  To run the bot:"
echo "    cd $REPO_DIR"
echo "    source ~/.zshrc"
echo "    npx opencode-telegram-mirror /root/projects"
echo
