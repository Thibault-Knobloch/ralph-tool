#!/bin/bash

# Fix SSH socket permissions if it exists (runs as root)
if [ -S "/run/host-services/ssh-auth.sock" ]; then
  chmod 666 /run/host-services/ssh-auth.sock
fi

# Fix gh config permissions
if [ -d "/home/node/.config/gh" ]; then
  chown -R node:node /home/node/.config/gh
fi

# Fix claude config permissions (volume mounts as root)
if [ -d "/home/node/.config/claude" ]; then
  chown -R node:node /home/node/.config/claude
fi

# Set git identity from environment or defaults
if [ -n "$GIT_USER_NAME" ]; then
  git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "$GIT_USER_EMAIL" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi

# Switch to node user and run the command
exec gosu node "$@"
