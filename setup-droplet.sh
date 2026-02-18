#!/usr/bin/env bash
#
# setup-droplet.sh — Automated setup for Claude Code Telegram bot on a fresh DigitalOcean droplet
#
# Usage: bash setup-droplet.sh
#
# This script automates the steps documented in docs/droplet-setup-explained.md.
# It will prompt you interactively for secrets and pause for manual steps (e.g., adding SSH key to GitHub).
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
# Section 1: System packages
# ---------------------------------------------------------------------------

info "Section 1: Installing system packages"

apt update
apt install -y zsh build-essential procps curl file git gh
apt install -y curl python3-venv python3-pip

ok "System packages installed"

# ---------------------------------------------------------------------------
# Section 1b: Oh My Zsh
# ---------------------------------------------------------------------------

info "Section 1b: Installing Oh My Zsh and setting Zsh as default shell"

if [ -d "$HOME/.oh-my-zsh" ]; then
    warn "Oh My Zsh is already installed — skipping"
else
    # RUNZSH=no prevents the installer from launching zsh (which would halt the script)
    # CHSH=yes sets zsh as the default login shell
    RUNZSH=no CHSH=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh My Zsh installed and Zsh set as default shell"
fi

# ---------------------------------------------------------------------------
# Section 2: SSH key for GitHub
# ---------------------------------------------------------------------------

info "Section 2: Setting up SSH key for GitHub"

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
# Section 3: GitHub CLI auth
# ---------------------------------------------------------------------------

info "Section 3: Authenticating GitHub CLI"

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
# Section 4: Poetry
# ---------------------------------------------------------------------------

info "Section 4: Installing Poetry"

export PATH="$HOME/.local/bin:$PATH"

if command -v poetry &>/dev/null; then
    warn "Poetry is already installed ($(poetry --version)) — skipping"
else
    curl -sSL https://install.python-poetry.org | python3 -

    # Add to zshrc if not already there
    if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi

    ok "Poetry installed ($(poetry --version))"
fi

# ---------------------------------------------------------------------------
# Section 5: Claude Code
# ---------------------------------------------------------------------------

info "Section 5: Installing Claude Code"

if command -v claude &>/dev/null; then
    warn "Claude Code is already installed — skipping"
else
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code installed"
fi

echo
read -rsp "  Enter your Anthropic API key: " ANTHROPIC_KEY
echo

# Add to zshrc if not already there
if ! grep -q 'ANTHROPIC_API_KEY' "$HOME/.zshrc" 2>/dev/null; then
    echo "export ANTHROPIC_API_KEY=\"$ANTHROPIC_KEY\"" >> "$HOME/.zshrc"
    ok "ANTHROPIC_API_KEY added to ~/.zshrc"
else
    warn "ANTHROPIC_API_KEY already in ~/.zshrc — skipping (update manually if needed)"
fi

export ANTHROPIC_API_KEY="$ANTHROPIC_KEY"

# ---------------------------------------------------------------------------
# Section 6: Clone and setup bot
# ---------------------------------------------------------------------------

info "Section 6: Cloning and setting up the bot"

REPO_DIR="$HOME/claude-code-telegram"

if [ -d "$REPO_DIR" ]; then
    warn "Repo already exists at $REPO_DIR — skipping clone"
else
    git clone git@github.com:RichardAtCT/claude-code-telegram.git "$REPO_DIR"
    ok "Repo cloned"
fi

cd "$REPO_DIR"

info "Running make dev (installing Python dependencies)"
make dev
ok "Dependencies installed"

# Apply tool_name -> name bug fix
info "Applying tool_name bug fix"
sed -i 's/getattr(block, "tool_name", "unknown")/getattr(block, "name", "unknown")/g' "$REPO_DIR/src/claude/sdk_integration.py"
ok "Bug fix applied to sdk_integration.py"

# ---------------------------------------------------------------------------
# Section 7: Configure .env
# ---------------------------------------------------------------------------

info "Section 7: Configuring .env"

mkdir -p /root/projects

echo
echo "  You need a Telegram bot token from @BotFather."
echo "  If you haven't created one yet, open Telegram, message @BotFather,"
echo "  send /newbot, and follow the prompts."
echo
read -rp  "  Telegram bot token: " TG_TOKEN
read -rp  "  Telegram bot username (without @): " TG_USERNAME
echo
echo "  Enter your Telegram user ID(s). To find yours, message @userinfobot on Telegram."
echo "  For multiple users, separate with commas (e.g., 123456,789012)."
read -rp  "  Allowed user IDs: " ALLOWED_USERS

cat > "$REPO_DIR/.env" <<EOF
TELEGRAM_BOT_TOKEN=$TG_TOKEN
TELEGRAM_BOT_USERNAME=$TG_USERNAME
APPROVED_DIRECTORY=/root/projects
ALLOWED_USERS=$ALLOWED_USERS
USE_SDK=true
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
echo "    - System packages (zsh, git, gh, python3, build tools)"
echo "    - Oh My Zsh (default shell)"
echo "    - SSH key for GitHub"
echo "    - GitHub CLI authenticated"
echo "    - Poetry (Python package manager)"
echo "    - Claude Code CLI"
echo "    - Bot repo cloned to $REPO_DIR"
echo "    - Bot dependencies installed"
echo "    - tool_name bug fix applied"
echo "    - .env configured"
echo
echo "  To run the bot:"
echo "    cd $REPO_DIR"
echo "    source ~/.zshrc"
echo "    make run-debug    # first run (shows logs)"
echo "    make run           # production mode"
echo
