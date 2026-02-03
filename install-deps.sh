#!/bin/bash
# AI Pipeline Worker - Install dependencies only (Docker, Docker Compose, GitHub CLI).
# No source code embedded; run from repo root. Use: ./install-deps.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step()   { echo -e "\n${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }

detect_os() {
  print_step "Detecting OS..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    DISTRO="macos"
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS="linux"
    DISTRO="${ID:-unknown}"
  else
    print_error "Unsupported OS"
    exit 1
  fi
  print_success "Detected: $OS ($DISTRO)"
}

install_docker() {
  print_step "Checking Docker..."
  if command -v docker &> /dev/null; then
    print_success "Docker already installed: $(docker --version)"
    return
  fi

  print_step "Installing Docker..."
  if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &> /dev/null; then
      print_step "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install --cask docker
    echo ""
    print_warning "Docker Desktop was installed. Please:"
    echo "  1. Open Docker Desktop from Applications"
    echo "  2. Wait for it to start"
    echo "  3. Re-run: ./install-deps.sh  (or ./setup.sh up -d)"
    exit 0
  else
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || true
    print_success "Docker installed"
  fi
}

install_docker_compose() {
  print_step "Checking Docker Compose..."
  if docker compose version &> /dev/null 2>&1; then
    print_success "Docker Compose available (plugin)"
    return
  fi
  if command -v docker-compose &> /dev/null && docker-compose version &> /dev/null 2>&1; then
    print_success "Docker Compose available (standalone)"
    return
  fi
  if [[ "$OS" == "linux" ]]; then
    print_step "Installing Docker Compose plugin..."
    sudo apt-get update -qq
    sudo apt-get install -y docker-compose-plugin
    print_success "Docker Compose installed"
  elif [[ "$OS" == "macos" ]]; then
    print_step "Installing Docker Compose (standalone via Homebrew)..."
    if ! command -v brew &> /dev/null; then
      print_step "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install docker-compose
    print_success "Docker Compose installed"
  else
    print_warning "Docker Compose not found. Install it manually for your OS."
  fi
}

install_gh() {
  print_step "Checking GitHub CLI (gh)..."
  if command -v gh &> /dev/null; then
    print_success "gh already installed: $(gh --version 2>/dev/null | head -1 || echo 'gh')"
    return
  fi

  print_step "Installing GitHub CLI..."
  if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &> /dev/null; then
      print_step "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install gh
    print_success "gh installed"
  else
    # Debian/Ubuntu (same as Dockerfile)
    sudo apt-get update -qq
    sudo apt-get install -y curl
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y gh
    print_success "gh installed"
  fi
}

install_git() {
  print_step "Checking Git..."
  if command -v git &> /dev/null; then
    print_success "Git already installed"
    return
  fi
  print_step "Installing Git..."
  if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &> /dev/null; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install git
  else
    sudo apt-get update -qq && sudo apt-get install -y git
  fi
  print_success "Git installed"
}

install_node() {
  print_step "Checking Node.js..."
  if command -v node &> /dev/null; then
    print_success "Node.js already installed: $(node --version)"
    return
  fi
  print_step "Installing Node.js..."
  if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &> /dev/null; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install node
  else
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
  print_success "Node.js installed"
}

install_claude_cli() {
  print_step "Checking Claude Code CLI..."
  if command -v claude &> /dev/null; then
    print_success "Claude CLI already installed: $(claude --version 2>/dev/null || echo 'installed')"
    return
  fi
  print_step "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
  print_success "Claude CLI installed"
}

setup_claude_auth() {
  if [[ -x "$SCRIPT_DIR/setup-claude.sh" ]]; then
    "$SCRIPT_DIR/setup-claude.sh"
    return
  fi
  print_step "Setting up Claude authentication (Max subscription / OAuth)..."
  if [[ -f "$HOME/.claude/.credentials.json" ]] || [[ -f "$HOME/.claude.json" ]]; then
    print_success "Already logged into Claude (credentials found)"
    return
  fi
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  CLAUDE LOGIN REQUIRED${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  This will open a browser to log in with your Claude account."
  echo "  Your subscription will be used (NOT API credits)."
  echo ""
  read -p "  Press ENTER to log in..." _
  claude auth login
  if [[ -f "$HOME/.claude/.credentials.json" ]] || [[ -f "$HOME/.claude.json" ]]; then
    print_success "Claude authentication successful!"
  else
    print_error "Claude login failed. Please run: claude auth login"
    exit 1
  fi
}

setup_ssh_key() {
  print_step "Setting up SSH key for GitHub..."
  SSH_KEY_PATH="$HOME/.ssh/ai_pipeline"
  KEY_ALREADY_EXISTED=0
  [[ -f "$SSH_KEY_PATH" ]] && KEY_ALREADY_EXISTED=1
  # Have .pub but no private key (e.g. copied only .pub from server): don't overwrite, ask for private key
  if [[ -f "${SSH_KEY_PATH}.pub" ]] && [[ ! -f "$SSH_KEY_PATH" ]]; then
    print_warning "You have ai_pipeline.pub but not the private key."
    echo "  Copy the private key from the server: scp -P 22 root@SERVER:~/.ssh/ai_pipeline $HOME/.ssh/ai_pipeline"
    echo "  Then run setup again."
    return
  fi
  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    ssh-keygen -t ed25519 -C "ai-worker-$(hostname)" -f "$SSH_KEY_PATH" -N ""
    print_success "SSH key generated"
  else
    print_success "SSH key already exists"
  fi
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  if ! grep -q "ai_pipeline" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config << EOF

Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
    StrictHostKeyChecking no
EOF
    chmod 600 ~/.ssh/config
  fi
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    print_success "GitHub SSH connection verified!"
    return
  fi

  # Try to add the key automatically via GitHub CLI only when the key was just created
  if [[ $KEY_ALREADY_EXISTED -eq 0 ]] && command -v gh &> /dev/null; then
    print_step "Adding SSH key to GitHub via gh (browser login)..."
    if ! gh auth status &> /dev/null; then
      echo ""
      echo -e "${YELLOW}  GitHub login required. A browser window will open.${NC}"
      read -p "  Press ENTER to open GitHub login..." _
      gh auth login --web --git-protocol ssh
    fi
    if gh auth status &> /dev/null; then
      if gh ssh-key add "${SSH_KEY_PATH}.pub" -t "ai-pipeline-worker-$(hostname)" 2>/dev/null; then
        print_success "SSH key added to GitHub automatically!"
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
          print_success "GitHub SSH connection verified!"
          return
        fi
      fi
    fi
  fi

  # Key already existed (e.g. copied from server): don't show "ADD THIS KEY" again, just warn and continue
  if [[ $KEY_ALREADY_EXISTED -eq 1 ]]; then
    print_warning "GitHub SSH not verified. If this key is already on GitHub, you're good."
    echo "  Otherwise add ${SSH_KEY_PATH}.pub at https://github.com/settings/keys"
    return
  fi

  # Fallback: show key and ask user to add manually (only when key was just created)
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  ADD THIS SSH KEY TO GITHUB:${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  cat "${SSH_KEY_PATH}.pub"
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "  Go to: https://github.com/settings/keys → New SSH key"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  read -p "Press ENTER after adding the key to GitHub..." _
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    print_success "GitHub SSH connection verified!"
  else
    print_warning "Could not verify GitHub connection. Continuing anyway..."
  fi
}

main() {
  echo -e "${CYAN}AI Pipeline Worker - Install dependencies${NC}"
  detect_os
  install_git
  install_docker
  install_docker_compose
  install_gh
  install_node
  install_claude_cli

  # Skip auth if called from setup.sh (SKIP_AUTH=1)
  if [[ "${SKIP_AUTH:-}" != "1" ]]; then
    setup_ssh_key
    setup_claude_auth
    echo ""
    print_success "Dependencies and auth OK. Next: create/edit .env and run ./setup.sh up -d"
  else
    echo ""
    print_success "Dependencies installed. Auth will be handled by setup.sh"
  fi
}

main "$@"
