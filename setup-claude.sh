#!/bin/bash
# AI Pipeline Worker - Universal Claude auth (macOS + Linux)
# Automatically detects OS and extracts token accordingly

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step()    { echo -e "\n${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }

# Extract OAuth token - UNIVERSAL (macOS + Linux)
extract_oauth_token() {
  local token=""
  
  # Try macOS Keychain first
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local keychain_data
    keychain_data=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || true
    if [[ -n "$keychain_data" ]]; then
      token=$(echo "$keychain_data" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
      if [[ -n "$token" ]]; then
        echo "$token"
        return 0
      fi
    fi
  fi
  
  # Try Linux credentials file
  local creds_file="$HOME/.claude/.credentials.json"
  if [[ -f "$creds_file" ]]; then
    token=$(cat "$creds_file" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
    if [[ -n "$token" ]]; then
      echo "$token"
      return 0
    fi
  fi
  
  return 1
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

  # Update or add CLAUDE_CODE_OAUTH_TOKEN (works on both macOS and Linux)
  if grep -q "^CLAUDE_CODE_OAUTH_TOKEN=" "$env_file" 2>/dev/null; then
    # macOS needs '', Linux doesn't - this works on both
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s|^CLAUDE_CODE_OAUTH_TOKEN=.*|CLAUDE_CODE_OAUTH_TOKEN=$token|" "$env_file"
    else
      sed -i "s|^CLAUDE_CODE_OAUTH_TOKEN=.*|CLAUDE_CODE_OAUTH_TOKEN=$token|" "$env_file"
    fi
  else
    echo "CLAUDE_CODE_OAUTH_TOKEN=$token" >> "$env_file"
  fi
  print_success "OAuth token saved to .env"
}

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux"
  else
    echo "Unknown"
  fi
}

if ! command -v claude &> /dev/null; then
  print_error "Claude CLI not found."
  echo ""
  echo "  Install: npm install -g @anthropic-ai/claude-code"
  echo ""
  exit 1
fi

OS=$(detect_os)
print_step "Setting up Claude authentication on $OS..."

# Try to extract existing token
OAUTH_TOKEN=$(extract_oauth_token 2>/dev/null || echo "")

if [[ -n "$OAUTH_TOKEN" ]]; then
  print_success "Claude OAuth token found!"
  save_token_to_env "$OAUTH_TOKEN"
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  ✓ Token extracted and saved${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Next steps:"
  echo "  docker compose down"
  echo "  docker compose up -d --build"
  echo ""
  exit 0
fi

# Need to login
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  CLAUDE LOGIN REQUIRED${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  This will open a browser to log in with your Claude account."
echo ""
read -p "  Press ENTER to continue..." _

claude auth login

# Wait for credentials to be saved
sleep 2

# Extract the token
OAUTH_TOKEN=$(extract_oauth_token 2>/dev/null || echo "")

if [[ -n "$OAUTH_TOKEN" ]]; then
  print_success "Claude authentication successful!"
  save_token_to_env "$OAUTH_TOKEN"
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  ✓ SUCCESS! Token saved to .env${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Rebuild Docker:"
  echo "     docker compose down"
  echo "     docker compose up -d --build"
  echo ""
  echo "  2. Test:"
  echo "     docker exec ai-pipeline-worker-worker-1 claude \"hello\""
  echo ""
  echo "  3. Copy token to other servers (optional):"
  echo "     Token is in: $SCRIPT_DIR/.env"
  echo "     Copy the CLAUDE_CODE_OAUTH_TOKEN line to other machines"
  echo ""
else
  print_error "Could not extract OAuth token"
  echo ""
  print_warning "Manual steps:"
  
  if [[ "$OS" == "macOS" ]]; then
    echo "  Check keychain:"
    echo "  security find-generic-password -s \"Claude Code-credentials\" -w"
  else
    echo "  Check credentials file:"
    echo "  cat ~/.claude/.credentials.json"
  fi
  
  echo ""
  echo "  Then manually add to .env:"
  echo "  CLAUDE_CODE_OAUTH_TOKEN=<your_token>"
  echo ""
  exit 1
fi