#!/bin/bash
# AI Pipeline Worker - Claude auth only. Run when you want to (re)do just Claude login.
# Also used by install-deps.sh. Usage: ./setup-claude.sh

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

# Extract OAuth token from macOS keychain
extract_oauth_token() {
  if [[ "$OSTYPE" != "darwin"* ]]; then
    return 1
  fi
  # Get the keychain data for Claude Code credentials
  local keychain_data
  keychain_data=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || return 1
  # Extract accessToken from JSON
  echo "$keychain_data" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4
}

# Save OAuth token to .env file
save_token_to_env() {
  local token="$1"
  local env_file="$SCRIPT_DIR/.env"

  if [[ ! -f "$env_file" ]]; then
    if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
      cp "$SCRIPT_DIR/.env.example" "$env_file"
    else
      touch "$env_file"
    fi
  fi

  # Update or add CLAUDE_CODE_OAUTH_TOKEN
  if grep -q "^CLAUDE_CODE_OAUTH_TOKEN=" "$env_file" 2>/dev/null; then
    # Update existing line (macOS compatible sed)
    sed -i '' "s|^CLAUDE_CODE_OAUTH_TOKEN=.*|CLAUDE_CODE_OAUTH_TOKEN=$token|" "$env_file"
  else
    echo "CLAUDE_CODE_OAUTH_TOKEN=$token" >> "$env_file"
  fi
  print_success "OAuth token saved to .env"
}

if ! command -v claude &> /dev/null; then
  print_error "Claude CLI not found."
  echo ""
  echo "  Install dependencies first: ./install-deps.sh"
  echo "  Or install manually: npm install -g @anthropic-ai/claude-code"
  echo ""
  exit 1
fi

print_step "Setting up Claude authentication (Max subscription / OAuth)..."

# Check if already logged in (token in keychain)
OAUTH_TOKEN=$(extract_oauth_token 2>/dev/null || echo "")

if [[ -n "$OAUTH_TOKEN" ]]; then
  print_success "Claude OAuth token found in keychain"
  save_token_to_env "$OAUTH_TOKEN"
  exit 0
fi

# Check for credentials file (legacy check)
if [[ -f "$HOME/.claude/.credentials.json" ]] || [[ -f "$HOME/.claude.json" ]]; then
  # Try to extract token from keychain anyway
  OAUTH_TOKEN=$(extract_oauth_token 2>/dev/null || echo "")
  if [[ -n "$OAUTH_TOKEN" ]]; then
    print_success "Claude OAuth token found"
    save_token_to_env "$OAUTH_TOKEN"
    exit 0
  fi
  print_warning "Credentials file exists but OAuth token not found in keychain"
  print_warning "Will proceed with login to refresh token..."
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

# After login, extract and save the OAuth token
sleep 1  # Give keychain a moment to update
OAUTH_TOKEN=$(extract_oauth_token 2>/dev/null || echo "")

if [[ -n "$OAUTH_TOKEN" ]]; then
  print_success "Claude authentication successful!"
  save_token_to_env "$OAUTH_TOKEN"
else
  print_error "Could not extract OAuth token from keychain"
  print_warning "You may need to manually set CLAUDE_CODE_OAUTH_TOKEN in .env"
  exit 1
fi
