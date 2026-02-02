#!/bin/bash
echo "═══════════════════════════════════════"
echo "       AI PIPELINE WORKER STATUS        "
echo "═══════════════════════════════════════"
docker compose ps
echo ""
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || true
