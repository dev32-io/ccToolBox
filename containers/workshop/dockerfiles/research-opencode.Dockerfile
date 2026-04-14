FROM node:20-slim

ARG OPENCODE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  curl \
  jq \
  less \
  python3 \
  python3-pip \
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

# Ensure proper ownership of all node user directories
RUN mkdir -p /home/node/.local/share/opencode /home/node/.config/opencode /workspace && \
  chown -R node:node /home/node/.local /home/node/.config /workspace

USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
USER root
RUN mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share/npm-global
USER node
RUN npm install -g opencode-ai@${OPENCODE_VERSION}

WORKDIR /workspace
ENV SHELL=/bin/bash
ENV TZ=America/Vancouver

COPY entrypoint-light-opencode.sh /usr/local/bin/entrypoint.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
