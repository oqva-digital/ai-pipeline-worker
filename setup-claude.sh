#!/bin/bash
# AI Pipeline Worker - Claude auth only. Run when you want to (re)do just Claude login.
# Also used by install-deps.sh. Usage: ./setup-claude.sh

set -e

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

if ! command -v claude &> /dev/null; then
  print_error "Claude CLI not found."
  echo ""
  echo "  Install dependencies first: ./install-deps.sh"
  echo "  Or install manually: npm install -g @anthropic-ai/claude-code"
  echo ""
  exit 1
fi

print_step "Setting up Claude authentication (Max subscription / OAuth)..."
if [[ -f "$HOME/.claude/.credentials.json" ]] || [[ -f "$HOME/.claude.json" ]]; then
  print_success "Already logged into Claude (credentials found)"
  exit 0
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
  print_error "Claude login failed. Try again: ./setup-claude.sh"
  exit 1
fi
