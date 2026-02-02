#!/bin/bash
# Get current number of workers
CURRENT=$(docker compose ps -q worker 2>/dev/null | wc -l | tr -d ' ')
CURRENT=${CURRENT:-1}
if [ "$CURRENT" -eq 0 ]; then
    CURRENT=1
fi
echo "Restarting with $CURRENT worker(s)..."
docker compose down
docker compose up -d --scale worker=$CURRENT --build
docker compose logs -f
