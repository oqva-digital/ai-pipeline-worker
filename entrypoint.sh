#!/bin/bash

# This runs as root first

# Copy SSH keys with correct ownership
if [ -d /tmp/.ssh-mount ]; then
    cp /tmp/.ssh-mount/* /home/worker/.ssh/ 2>/dev/null || true
    chown -R worker:worker /home/worker/.ssh
    chmod 700 /home/worker/.ssh
    chmod 600 /home/worker/.ssh/* 2>/dev/null || true
    chmod 644 /home/worker/.ssh/*.pub 2>/dev/null || true
fi

# Add GitHub to known hosts
ssh-keyscan github.com >> /home/worker/.ssh/known_hosts 2>/dev/null
chown worker:worker /home/worker/.ssh/known_hosts

# Configure SSH to use ai_pipeline key
cat > /home/worker/.ssh/config << 'SSHCONFIG'
Host github.com
    HostName github.com
    User git
    IdentityFile /home/worker/.ssh/ai_pipeline
    IdentitiesOnly yes
    StrictHostKeyChecking no
SSHCONFIG
chown worker:worker /home/worker/.ssh/config
chmod 600 /home/worker/.ssh/config

# ═══════════════════════════════════════════════════════════════
# Claude CLI Setup - Create fresh writable directory
# ═══════════════════════════════════════════════════════════════

# Remove any existing .claude (might be from image)
rm -rf /home/worker/.claude

# Create fresh directory structure
mkdir -p /home/worker/.claude/debug
mkdir -p /home/worker/.claude/todos
mkdir -p /home/worker/.claude/projects
mkdir -p /home/worker/.claude/statsig

# Copy credentials from mounted file
if [ -f /tmp/.claude-credentials.json ]; then
    cp /tmp/.claude-credentials.json /home/worker/.claude/.credentials.json
    echo "Copied Claude credentials"
else
    echo "WARNING: Claude credentials not found at /tmp/.claude-credentials.json"
fi

# Fix permissions
chown -R worker:worker /home/worker/.claude
chmod -R 755 /home/worker/.claude
chmod 600 /home/worker/.claude/.credentials.json 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# GitHub CLI Setup - Auth with token
# ═══════════════════════════════════════════════════════════════
if [ -n "$GITHUB_TOKEN" ]; then
    echo "$GITHUB_TOKEN" | su worker -c "gh auth login --with-token"
    echo "GitHub CLI authenticated"
fi

# Debug output
echo "=== Claude Setup ==="
ls -la /home/worker/.claude/
echo "===================="
# Switch to worker user and run node
exec su worker -c "node /app/worker.js"

