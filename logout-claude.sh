#!/bin/bash
# AI Pipeline Worker - Remove Claude credentials (logout).
# Usage: ./logout-claude.sh [--yes]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step()   { echo -e "\n${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

CRED_JSON="$HOME/.claude/.credentials.json"
CLAUDE_JSON="$HOME/.claude.json"
CLAUDE_DIR="$HOME/.claude"

CONFIRM=1
[[ "$1" == "-y" || "$1" == "--yes" ]] && CONFIRM=0

print_step "Removing Claude credentials..."

REMOVED=0

if [[ -f "$CRED_JSON" ]]; then
  if [[ $CONFIRM -eq 1 ]]; then
    echo ""
    echo "  This will remove: $CRED_JSON"
    echo "  You will need to run ./setup-claude.sh (or claude auth login) to log in again."
    echo ""
    read -p "  Continue? [y/N]: " ans
    case "$ans" in [yY]|[yY][eE][sS]) ;; *) echo "  Cancelled."; exit 0; ;; esac
  fi
  rm -f "$CRED_JSON"
  print_success "Removed $CRED_JSON"
  REMOVED=1
fi

if [[ -f "$CLAUDE_JSON" ]]; then
  if [[ $CONFIRM -eq 1 && $REMOVED -eq 0 ]]; then
    echo ""
    echo "  This will remove: $CLAUDE_JSON"
    echo "  You will need to run ./setup-claude.sh (or claude auth login) to log in again."
    echo ""
    read -p "  Continue? [y/N]: " ans
    case "$ans" in [yY]|[yY][eE][sS]) ;; *) echo "  Cancelled."; exit 0; ;; esac
  fi
  rm -f "$CLAUDE_JSON"
  print_success "Removed $CLAUDE_JSON"
  REMOVED=1
fi

if [[ $REMOVED -eq 0 ]]; then
  print_warning "No Claude credentials found at $CRED_JSON or $CLAUDE_JSON"
  exit 0
fi

# Remove .claude dir if empty (optional, keeps other files like settings)
if [[ -d "$CLAUDE_DIR" ]]; then
  if [[ -z "$(ls -A "$CLAUDE_DIR" 2>/dev/null)" ]]; then
    rmdir "$CLAUDE_DIR" 2>/dev/null && print_success "Removed empty $CLAUDE_DIR" || true
  fi
fi

echo ""
print_success "Claude credentials removed. Run ./setup-claude.sh to log in again."
