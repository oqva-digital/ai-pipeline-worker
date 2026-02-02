FROM node:20-slim

RUN apt-get update && apt-get install -y git curl openssh-client && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Create worker user
RUN useradd -m worker

# Create writable directories for Claude CLI
RUN mkdir -p /home/worker/.claude/debug \
    /home/worker/.claude/todos \
    /home/worker/.claude/projects \
    /home/worker/.claude/statsig \
    /home/worker/.ssh \
    /home/worker/repos \
    && chown -R worker:worker /home/worker

# Git config
RUN su worker -c "git config --global user.email 'ai-worker@pipeline.local'" \
    && su worker -c "git config --global user.name 'AI Pipeline Worker'"

WORKDIR /app
COPY package.json worker.js entrypoint.sh ./
RUN npm install && chmod +x /app/entrypoint.sh

# Run as root initially, entrypoint will switch to worker
ENTRYPOINT ["/app/entrypoint.sh"]
