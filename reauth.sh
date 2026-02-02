#!/bin/bash
echo "Re-authenticating Claude..."
claude auth login
echo "Restarting workers to pick up new credentials..."
docker compose down
docker compose up -d --build
echo "Done!"
