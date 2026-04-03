FROM node:20-slim

ARG CLAUDE_CODE_VERSION=latest

# --- Base tools (same as offline-research) ---

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  curl \
  jq \
  less \
  python3 \
  python3-pip \
  python3-venv \
  ripgrep \
  build-essential \
  tree \
  unzip \
  wget \
  sqlite3 \
  nano \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- PoC build dependencies ---

# Bun runtime
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash

# Rust toolchain
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=$PATH:/usr/local/cargo/bin
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

# Go
RUN apt-get update && apt-get install -y --no-install-recommends golang-go \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Node.js ecosystem
USER root
RUN npm install -g typescript ts-node tsx pnpm

# Databases & storage
RUN apt-get update && apt-get install -y --no-install-recommends \
  libsqlite3-dev \
  redis-tools \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Headless browser
RUN apt-get update && apt-get install -y --no-install-recommends \
  chromium \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN npm install -g playwright && npx playwright install --with-deps chromium

# Build tools & common libs
RUN apt-get update && apt-get install -y --no-install-recommends \
  cmake \
  pkg-config \
  libssl-dev \
  protobuf-compiler \
  net-tools \
  dnsutils \
  iputils-ping \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Security: poc user for sandboxed code execution ---

RUN useradd -m -s /bin/bash poc

# --- Non-root user setup ---

# .private/ is 700 owned by node — poc user cannot traverse it.
# .claude/ is mounted inside .private/ at runtime, then symlinked from ~/.claude.
# This ensures poc user cannot read auth tokens even if host permissions are permissive.
RUN mkdir -p /home/node/.private /workspace && \
  chown node:node /home/node/.private && \
  chmod 700 /home/node/.private && \
  chown -R node:node /workspace

USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
USER root
RUN mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share/npm-global
USER node
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

WORKDIR /workspace
ENV SHELL=/bin/bash
ENV TZ=America/Vancouver

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
