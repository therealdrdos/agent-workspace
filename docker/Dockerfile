# checkov:skip=CKV_DOCKER_3:Container requires root to fix permissions at runtime (entrypoint)
# trivy:ignore:AVD-DS-0002
# kics-scan disable=fd54f200-402c-4333-a5a4-36ef6709af2f
FROM node:24-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# checkov:skip=CKV2_DOCKER_1:Sudo is needed for dev environment
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    coreutils \
    curl \
    jq \
    less \
    procps \
    ripgrep \
    sudo \
    tzdata \
    git \
    && rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3016
RUN npm install -g \
    @anthropic-ai/claude-code \
    @google/gemini-cli \
    @openai/codex \
    && npm cache clean --force

# yolo wrappers
RUN printf '#!/bin/sh\nexec claude --dangerously-skip-permissions "$@"\n' > /usr/local/bin/claude-yolo && \
    printf '#!/bin/sh\nexec gemini --yolo "$@"\n' > /usr/local/bin/gemini-yolo && \
    printf '#!/bin/sh\nexec codex --yolo "$@"\n' > /usr/local/bin/codex-yolo && \
    chmod +x /usr/local/bin/claude-yolo /usr/local/bin/gemini-yolo /usr/local/bin/codex-yolo

# rename node -> dev, add sudo
RUN usermod -l dev -d /home/dev -m node \
    && groupmod -n dev node \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

RUN mkdir -p /home/dev/.config /home/dev/.cache /home/dev/.local \
    && chown -R dev:dev /home/dev

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace

# No need for a healthcheck
HEALTHCHECK NONE

# entrypoint may adjust UID/GID on Linux
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
