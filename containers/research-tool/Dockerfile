FROM node:20-slim

ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  gh \
  curl \
  jq \
  less \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN mkdir -p /home/node/.claude /workspace && \
  chown -R node:node /home/node/.claude /workspace

USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
USER root
RUN mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share/npm-global
USER node
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

WORKDIR /workspace
ENV SHELL=/bin/bash

ENTRYPOINT ["bash"]
