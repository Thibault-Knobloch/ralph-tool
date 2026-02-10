FROM node:20-bookworm

# System deps
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
  git bash ca-certificates curl ripgrep openssh-client \
  jq bsdutils bc gosu \
  && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update && apt-get install -y gh \
  && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Install ralph-tool globally from source
COPY . /tmp/ralph-tool
RUN npm install -g /tmp/ralph-tool && rm -rf /tmp/ralph-tool \
  && ln -sf $(which ralph) /usr/local/bin/ralph

# Prepare writable config dirs for the non-root user
RUN mkdir -p /home/node/.config /home/node/.cache /home/node/.ssh \
  && chown -R node:node /home/node/.config /home/node/.cache /home/node/.ssh

# Add GitHub's SSH host key to known_hosts
RUN ssh-keyscan github.com >> /home/node/.ssh/known_hosts \
  && chown node:node /home/node/.ssh/known_hosts

# Add entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace
ENV TERM=xterm-256color

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
