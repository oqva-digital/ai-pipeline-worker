#!/bin/bash
# AI Pipeline Worker - Complete interactive setup
# Installs dependencies, authenticates services (GitHub, Claude), and starts containers.
#
# Usage:
#   ./setup.sh              - Full setup: install deps, auth, configure .env, start containers
#   ./setup.sh install      - Only install dependencies (Docker, gh, node, claude)
#   ./setup.sh auth         - Only run authentication (GitHub + Claude)
#   ./setup.sh up -d        - Load .env and run docker compose up -d
#   ./setup.sh logs -f      - Load .env and run docker compose logs -f

set -e
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step()    { echo -e "\n${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

ensure_env_file() {
  if [[ ! -f .env ]]; then
    if [[ -f .env.example ]]; then
      cp .env.example .env
      print_success "Created .env from .env.example"
    else
      touch .env
    fi
  fi
}

update_env_var() {
  local key="$1"
  local value="$2"
  local env_file=".env"

  ensure_env_file

  if grep -q "^${key}=" "$env_file" 2>/dev/null; then
    # Update existing (macOS compatible)
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
      sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    fi
  else
    echo "${key}=${value}" >> "$env_file"
  fi
}

get_env_var() {
  local key="$1"
  grep "^${key}=" .env 2>/dev/null | cut -d'=' -f2- | head -1
}

# ═══════════════════════════════════════════════════════════════
# GitHub Authentication (Headless)
# ═══════════════════════════════════════════════════════════════

setup_github_auth() {
  print_step "Setting up GitHub authentication..."

  # Check if already authenticated
  if gh auth status &>/dev/null; then
    print_success "GitHub CLI already authenticated"
    # Extract and save token to .env
    local token
    token=$(gh auth token 2>/dev/null || echo "")
    if [[ -n "$token" ]]; then
      update_env_var "GITHUB_TOKEN" "$token"
      print_success "GitHub token saved to .env"
    fi
    return 0
  fi

  # Check if token exists in .env
  local existing_token
  existing_token=$(get_env_var "GITHUB_TOKEN")
  if [[ -n "$existing_token" ]] && [[ "$existing_token" != "" ]]; then
    echo "$existing_token" | gh auth login --with-token 2>/dev/null && {
      print_success "GitHub authenticated from .env token"
      return 0
    }
  fi

  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  GITHUB LOGIN REQUIRED${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  A browser window will open (or show a URL to open manually)."
  echo "  Log in with your GitHub account and authorize the CLI."
  echo ""
  read -p "  Press ENTER to continue..." _

  # Use --web for headless-friendly auth with proper scopes
  gh auth login --web --git-protocol https --scopes "repo,read:org,gist"

  if gh auth status &>/dev/null; then
    print_success "GitHub authentication successful!"
    local token
    token=$(gh auth token 2>/dev/null || echo "")
    if [[ -n "$token" ]]; then
      update_env_var "GITHUB_TOKEN" "$token"
      print_success "GitHub token saved to .env"
    fi
  else
    print_error "GitHub authentication failed"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# Claude Authentication (Headless)
# ═══════════════════════════════════════════════════════════════

extract_claude_oauth_token() {
  if [[ "$OSTYPE" != "darwin"* ]]; then
    return 1
  fi
  local keychain_data
  keychain_data=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || return 1
  echo "$keychain_data" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4
}

create_claude_credentials() {
  local token="$1"
  local script_dir="$(cd "$(dirname "$0")" && pwd)"

  # Create .claude directory in project folder for Docker mount
  mkdir -p "$script_dir/.claude"

  # Create credentials.json from token
  cat > "$script_dir/.claude/.credentials.json" << CREDENTIALS
{
  "claudeAiOauth": {
    "accessToken": "$token"
  },
  "hasCompletedOnboarding": true
}
CREDENTIALS
  chmod 600 "$script_dir/.claude/.credentials.json"
  print_success "Claude credentials created in project folder (for Docker)"

  # Also create in home directory for local Claude CLI usage
  mkdir -p "$HOME/.claude"
  cp "$script_dir/.claude/.credentials.json" "$HOME/.claude/.credentials.json"
  chmod 600 "$HOME/.claude/.credentials.json"
  print_success "Claude credentials created in ~/.claude (for local CLI)"
}

setup_claude_auth() {
  print_step "Setting up Claude authentication..."

  if ! command -v claude &>/dev/null; then
    print_error "Claude CLI not found. Run: npm install -g @anthropic-ai/claude-code"
    return 1
  fi

  # Check if OAuth token already exists in keychain (macOS)
  local oauth_token
  oauth_token=$(extract_claude_oauth_token 2>/dev/null || echo "")

  if [[ -n "$oauth_token" ]]; then
    print_success "Claude OAuth token found in keychain"
    update_env_var "CLAUDE_CODE_OAUTH_TOKEN" "$oauth_token"
    print_success "Claude token saved to .env"
    # Create credentials.json for local CLI and Docker mount
    create_claude_credentials "$oauth_token"
    return 0
  fi

  # Check if token exists in .env
  local existing_token
  existing_token=$(get_env_var "CLAUDE_CODE_OAUTH_TOKEN")
  if [[ -n "$existing_token" ]] && [[ "$existing_token" != "" ]]; then
    print_success "Claude token found in .env"
    # Create credentials.json for local CLI and Docker mount
    create_claude_credentials "$existing_token"
    return 0
  fi

  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  CLAUDE LOGIN REQUIRED${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  A browser window will open to authenticate with Claude."
  echo "  Your Claude subscription will be used (NOT API credits)."
  echo ""
  read -p "  Press ENTER to continue..." _

  claude auth login

  # Wait for keychain to update
  sleep 2

  oauth_token=$(extract_claude_oauth_token 2>/dev/null || echo "")

  if [[ -n "$oauth_token" ]]; then
    print_success "Claude authentication successful!"
    update_env_var "CLAUDE_CODE_OAUTH_TOKEN" "$oauth_token"
    print_success "Claude token saved to .env"
    # Create credentials.json for local CLI and Docker mount
    create_claude_credentials "$oauth_token"
  else
    print_error "Could not extract Claude OAuth token"
    print_warning "On non-macOS systems, you may need to manually set CLAUDE_CODE_OAUTH_TOKEN"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# Redis URL Configuration
# ═══════════════════════════════════════════════════════════════

setup_redis_url() {
  print_step "Checking Redis configuration..."

  local redis_url
  redis_url=$(get_env_var "REDIS_URL")

  if [[ -n "$redis_url" ]] && [[ "$redis_url" != "" ]]; then
    print_success "Redis URL configured in .env"
    return 0
  fi

  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  REDIS URL REQUIRED${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  Enter your Redis connection URL."
  echo "  Example: redis://localhost:6379 or redis://user:pass@host:6379"
  echo ""
  read -p "  Redis URL: " redis_url

  if [[ -n "$redis_url" ]]; then
    update_env_var "REDIS_URL" "$redis_url"
    print_success "Redis URL saved to .env"
  else
    print_warning "No Redis URL provided. Edit .env manually before starting."
  fi
}

# ═══════════════════════════════════════════════════════════════
# Install Dependencies
# ═══════════════════════════════════════════════════════════════

run_install_deps() {
  if [[ -x "./install-deps.sh" ]]; then
    # Run install-deps but skip the auth parts (we handle auth separately)
    SKIP_AUTH=1 ./install-deps.sh
  else
    print_error "install-deps.sh not found or not executable"
    exit 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# Docker Compose
# ═══════════════════════════════════════════════════════════════

get_compose_cmd() {
  if docker compose version &>/dev/null; then
    echo "docker compose"
    return
  fi
  if command -v docker-compose &>/dev/null && docker-compose version &>/dev/null; then
    echo "docker-compose"
    return
  fi
  echo ""
}

run_compose() {
  local compose_cmd
  compose_cmd=$(get_compose_cmd)

  if [[ -z "$compose_cmd" ]]; then
    print_error "Docker Compose not available"
    echo ""
    echo "  If you just installed Docker Desktop, open the app and wait for it to start,"
    echo "  then run: ./setup.sh up -d"
    exit 1
  fi

  if ! docker info &>/dev/null; then
    print_error "Docker is not running"
    echo ""
    echo "  Open Docker Desktop and wait for it to start, then run: ./setup.sh up -d"
    exit 1
  fi

  ensure_env_file
  set -a
  . ./.env
  set +a
  exec $compose_cmd "$@"
}

# ═══════════════════════════════════════════════════════════════
# Full Setup Flow
# ═══════════════════════════════════════════════════════════════

run_full_setup() {
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║           AI Pipeline Worker - Interactive Setup            ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

  # Step 1: Install dependencies
  print_step "Installing dependencies..."
  run_install_deps

  # Step 2: Create .env if needed
  ensure_env_file

  # Step 3: GitHub authentication
  setup_github_auth || print_warning "GitHub auth skipped/failed"

  # Step 4: Claude authentication
  setup_claude_auth || print_warning "Claude auth skipped/failed"

  # Step 5: Redis configuration
  setup_redis_url

  # Step 6: Start containers
  print_step "Starting Docker containers..."

  local compose_cmd
  compose_cmd=$(get_compose_cmd)

  if [[ -z "$compose_cmd" ]]; then
    print_warning "Docker Compose not available yet"
    echo ""
    echo "  After Docker Desktop starts, run: ./setup.sh up -d"
    exit 0
  fi

  if ! docker info &>/dev/null; then
    print_warning "Docker is not running yet"
    echo ""
    echo "  After Docker Desktop starts, run: ./setup.sh up -d"
    exit 0
  fi

  set -a
  . ./.env
  set +a

  $compose_cmd up -d --build

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                    Setup Complete!                           ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "  Useful commands:"
  echo "    ./setup.sh logs -f     View container logs"
  echo "    ./setup.sh down        Stop containers"
  echo "    ./status.sh            Check worker status"
  echo "    ./reauth.sh            Re-authenticate services"
  echo ""
}

run_auth_only() {
  echo -e "${CYAN}AI Pipeline Worker - Authentication${NC}"
  ensure_env_file
  setup_github_auth || print_warning "GitHub auth skipped/failed"
  setup_claude_auth || print_warning "Claude auth skipped/failed"
  print_success "Authentication complete. Run: ./setup.sh up -d"
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

case "${1:-}" in
  install|deps)
    run_install_deps
    ;;
  auth)
    run_auth_only
    ;;
  "")
    run_full_setup
    ;;
  *)
    ensure_env_file
    run_compose "$@"
    ;;
esac
