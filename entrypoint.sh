#!/bin/bash

# This runs as root first to handle permissions of mounted volumes
echo "=== SSH Setup ==="
if [ -d /tmp/.ssh-mount ]; then
    echo "Source files in /tmp/.ssh-mount:"
    ls -la /tmp/.ssh-mount/

    # Copy only key files
    for file in /tmp/.ssh-mount/ai_pipeline /tmp/.ssh-mount/ai_pipeline.pub; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "Copying $filename..."
            cp "$file" "/home/worker/.ssh/$filename"
        fi
    done

    # Strict permissions required by SSH
    chown -R worker:worker /home/worker/.ssh
    chmod 700 /home/worker/.ssh
    chmod 600 /home/worker/.ssh/ai_pipeline 2>/dev/null || true
    chmod 644 /home/worker/.ssh/ai_pipeline.pub 2>/dev/null || true
else
    echo "WARNING: /tmp/.ssh-mount not found!"
fi

# Setup known_hosts
touch /home/worker/.ssh/known_hosts
ssh-keyscan -t ed25519,rsa github.com > /home/worker/.ssh/known_hosts 2>/dev/null || true
chown worker:worker /home/worker/.ssh/known_hosts
chmod 600 /home/worker/.ssh/known_hosts

# SSH Config (Ensures worker always uses ai_pipeline for GitHub)
cat > /home/worker/.ssh/config << 'SSHCONFIG'
Host github.com
    HostName github.com
    User git
    IdentityFile /home/worker/.ssh/ai_pipeline
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
SSHCONFIG
chown worker:worker /home/worker/.ssh/config
chmod 600 /home/worker/.ssh/config

# ═══════════════════════════════════════════════════════════════
# Git Global Config (Fixes "Dubious Ownership" & Commit Identity)
# ═══════════════════════════════════════════════════════════════
su worker -c "git config --global user.email 'ai-worker@pipeline.local'"
su worker -c "git config --global user.name 'AI Pipeline Worker'"
su worker -c "git config --global --add safe.directory '*'"
echo "✓ Git configured for worker"

# ═══════════════════════════════════════════════════════════════
# Claude CLI Setup
# ═══════════════════════════════════════════════════════════════
rm -rf /home/worker/.claude
mkdir -p /home/worker/.claude/debug /home/worker/.claude/todos /home/worker/.claude/projects /home/worker/.claude/statsig

# ~/.claude.json: onboarding + MCP servers (MCP MUST be here, not in settings.json)
node -e "
const s = { hasCompletedOnboarding: true, theme: 'dark' };
const v0Key = process.env.V0_API_KEY;
if (v0Key) {
  s.mcpServers = {
    v0: {
      command: 'npx',
      args: ['mcp-remote','https://mcp.v0.dev','--header','Authorization: Bearer '+v0Key]
    }
  };
}
require('fs').writeFileSync('/home/worker/.claude.json', JSON.stringify(s,null,2));
"
chown worker:worker /home/worker/.claude.json

if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
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
    echo "✓ Claude credentials created"
fi

chown -R worker:worker /home/worker/.claude
chmod 600 /home/worker/.claude/.credentials.json 2>/dev/null || true

# GitHub CLI Auth
if [ -n "$GITHUB_TOKEN" ]; then
    echo "$GITHUB_TOKEN" | su worker -c "gh auth login --with-token"
fi

# Switch to worker and start
exec su worker -c "node /app/worker.js"