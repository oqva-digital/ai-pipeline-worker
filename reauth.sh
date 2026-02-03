#!/bin/bash
# Re-authenticate Claude and restart workers. Usage: ./reauth.sh [--logout]
# --logout = remove credentials first, then you'll be prompted to log in again.

set -e
cd "$(dirname "$0")"

if [[ "$1" == "--logout" ]]; then
  if [[ -x "./logout-claude.sh" ]]; then
    ./logout-claude.sh --yes
  else
    rm -f "$HOME/.claude/.credentials.json" "$HOME/.claude.json"
    echo "Credentials removed."
  fi
fi

if [[ -x "./setup-claude.sh" ]]; then
  ./setup-claude.sh
else
  echo "Re-authenticating Claude..."
  claude auth login
fi

echo "Restarting workers to pick up new credentials..."
if [[ -f .env ]]; then
  set -a
  . ./.env
  set +a
fi
docker compose down
docker compose up -d --build
echo "Done!"
