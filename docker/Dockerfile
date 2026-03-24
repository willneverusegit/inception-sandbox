FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install base tools + tmux + Node.js (for Claude Code CLI)
RUN apt-get update && apt-get install -y \
    tmux \
    curl \
    git \
    jq \
    python3 \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create workspace directory
RUN mkdir -p /workspace /output

# tmux config: no status bar, larger scrollback
RUN echo "set -g status off\nset -g history-limit 50000" > /root/.tmux.conf

WORKDIR /workspace

# Default: start tmux session named "agent"
CMD ["tmux", "new-session", "-d", "-s", "agent", "&&", "sleep", "infinity"]
