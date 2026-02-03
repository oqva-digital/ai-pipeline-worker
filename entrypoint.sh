#!/bin/bash

# This runs as root first

# Copy SSH keys with correct ownership
echo "=== SSH Setup ==="
if [ -d /tmp/.ssh-mount ]; then
    echo "Source files in /tmp/.ssh-mount:"
    ls -la /tmp/.ssh-mount/

    # Copy files individually to catch errors
    for file in /tmp/.ssh-mount/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "Copying $filename..."
            cp "$file" "/home/worker/.ssh/$filename"
        fi
    done

    chown -R worker:worker /home/worker/.ssh
    chmod 700 /home/worker/.ssh
    chmod 600 /home/worker/.ssh/* 2>/dev/null || true
    chmod 644 /home/worker/.ssh/*.pub 2>/dev/null || true

    echo "Result in /home/worker/.ssh:"
    ls -la /home/worker/.ssh/
else
    echo "WARNING: /tmp/.ssh-mount not found!"
fi
echo "===================="

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
# Claude CLI Setup - Create fresh writable directory with OAuth token
# ═══════════════════════════════════════════════════════════════

# Remove any existing .claude (might be from image)
rm -rf /home/worker/.claude

# Create fresh directory structure
mkdir -p /home/worker/.claude/debug
mkdir -p /home/worker/.claude/todos
mkdir -p /home/worker/.claude/projects
mkdir -p /home/worker/.claude/statsig

# Create credentials with OAuth tokens from environment
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    # Create complete credentials file with refresh token for auto-renewal
    cat > /home/worker/.claude/.credentials.json << CREDENTIALS
{
  "claudeAiOauth": {
    "accessToken": "$CLAUDE_CODE_OAUTH_TOKEN",
    "refreshToken": "${CLAUDE_CODE_REFRESH_TOKEN:-}",
    "expiresAt": ${CLAUDE_CODE_EXPIRES_AT:-0},
    "scopes": ["user:inference", "user:profile"]
  },
  "hasCompletedOnboarding": true
}
CREDENTIALS
    echo "Claude credentials created with refresh token support"
elif [ -f /tmp/.claude-credentials.json ]; then
    # Fallback: copy from mounted file (legacy)
    cp /tmp/.claude-credentials.json /home/worker/.claude/.credentials.json
    echo "Copied Claude credentials from mounted file"
else
    echo "WARNING: No Claude credentials found (set CLAUDE_CODE_OAUTH_TOKEN in .env)"
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

