#!/bin/bash
# AI Pipeline Worker - Setup: install deps (Docker, gh), .env, and Docker Compose.
# No source code embedded; uses versioned repo files.
# Usage:
#   ./setup.sh              - install deps, ensure .env, then start (docker compose up -d)
#   ./setup.sh install      - only install Docker, Docker Compose, gh
#   ./setup.sh up -d        - load .env and run docker compose up -d
#   ./setup.sh logs -f      - load .env and run docker compose logs -f

set -e
cd "$(dirname "$0")"

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

# --- Install dependencies (Docker, Docker Compose, gh) ---
run_install_deps() {
  if [[ -x "./install-deps.sh" ]]; then
    ./install-deps.sh
  else
    print_error "install-deps.sh not found or not executable. Run from repo root: chmod +x install-deps.sh && ./install-deps.sh"
    exit 1
  fi
}

# --- Ensure .env exists ---
ensure_env() {
  if [[ ! -f .env ]]; then
    print_step "No .env file found."
    if [[ -f .env.example ]]; then
      cp .env.example .env
      print_success "Created .env from .env.example."
      echo ""
      print_warning "Edit .env with REDIS_URL, GITHUB_TOKEN, etc., then run:"
      echo "  ./setup.sh up -d"
      echo ""
      exit 1
    else
      print_error "No .env.example. Create a .env with REDIS_URL, GITHUB_TOKEN and other required variables."
      exit 1
    fi
  fi
}

# --- Detect docker compose command (plugin "docker compose" or standalone "docker-compose") ---
get_compose_cmd() {
  if docker compose version &> /dev/null; then
    echo "docker compose"
    return
  fi
  if command -v docker-compose &> /dev/null && docker-compose version &> /dev/null; then
    echo "docker-compose"
    return
  fi
  echo ""
}

# --- Load .env and run docker compose ---
run_compose() {
  COMPOSE_CMD=$(get_compose_cmd)
  if [[ -z "$COMPOSE_CMD" ]]; then
    print_error "Docker Compose not available."
    echo ""
    echo "  - If you just installed Docker Desktop: open the app, wait until it is running,"
    echo "    then open a new terminal and run: ./setup.sh up -d"
    echo "  - Or install the plugin: https://docs.docker.com/compose/install/"
    echo ""
    exit 1
  fi
  if ! docker info &> /dev/null; then
    print_error "Docker is not running."
    echo ""
    echo "  Open Docker Desktop and wait until it starts, then run: ./setup.sh up -d"
    echo ""
    exit 1
  fi
  set -a
  . ./.env
  set +a
  exec $COMPOSE_CMD "$@"
}

# --- Main ---
case "${1:-}" in
  install|deps)
    run_install_deps
    exit 0
    ;;
  "")
    # First-time / default: install deps, ensure .env, then start
    run_install_deps
    ensure_env
    run_compose up -d
    exit 0
    ;;
  *)
    ensure_env
    run_compose "$@"
    ;;
esac
