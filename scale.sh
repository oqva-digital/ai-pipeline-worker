#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./scale.sh <num_workers>"
    echo "Current:"
    docker compose ps
    exit 0
fi
docker compose up -d --scale worker=$1 --build
docker compose ps
