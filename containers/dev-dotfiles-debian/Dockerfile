# syntax=docker/dockerfile:1.7

ARG DEBIAN_RELEASE=stable
FROM debian:${DEBIAN_RELEASE}-slim

LABEL org.opencontainers.image.description="Debian development container with dotfiles"

ARG USER_NAME=user
ARG USER_UID=1000
ARG USER_GID=1000
ARG CODEX_RELEASE=latest
ARG FLUTTER_CHANNEL=stable
ARG DOTFILES_RELEASE=unknown
ARG DOTFILES_COMMIT=unknown

ENV DEBIAN_FRONTEND=noninteractive \
  TZ=Etc/UTC \
  SHELL=/usr/bin/zsh \
  LANG=en_US.UTF-8 \
  LC_ALL=en_US.UTF-8

RUN set -euxo pipefail \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  curl \
  wget \
  ca-certificates \
  gnupg \
  gpg \
  gpg-agent \
  && mkdir -p -m 755 /etc/apt/keyrings \
  && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  jq \
  gh \
  git \
  openssh-client \
  sudo \
  zsh \
  vim \
  kdiff3 \
  diffutils \
  ripgrep \
  fd-find \
  fzf \
  tmux \
  htop \
  tree \
  build-essential \
  clang \
  clang-format \
  cmake \
  ninja-build \
  gdb \
  lldb \
  pkg-config \
  make \
  autoconf \
  automake \
  libtool \
  libssl-dev \
  sqlite3 \
  libsqlite3-dev \
  libgtk-3-dev \
  libglu1-mesa \
  libgl1 \
  liblzma-dev \
  python3 \
  python3-pip \
  python3-venv \
  golang \
  default-jdk \
  nodejs \
  npm \
  unzip \
  hugo \
  xz-utils \
  ca-certificates \
  locales \
  && GLAB_LATEST_URL=$(curl -sL https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases | jq -r '.[0].assets.links[] | select(.name | test("deb")) | .url' | grep -i "$(dpkg --print-architecture)" | head -n 1) \
  && curl -sL "$GLAB_LATEST_URL" -o glab.deb \
  && dpkg -i glab.deb \
  && rm glab.deb \
  && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
  && locale-gen \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --gid "${USER_GID}" "${USER_NAME}" \
  && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /usr/bin/zsh "${USER_NAME}" \
  && mkdir -p /etc/sudoers.d \
  && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} \
  && chmod 0440 /etc/sudoers.d/${USER_NAME} \
  && python3 -m pip install --no-cache-dir --break-system-packages "mini-swe-agent" \
  && curl -fsSL https://chatgpt.com/codex/install.sh \
    | CODEX_HOME=/opt/codex \
      CODEX_INSTALL_DIR=/usr/local/bin \
      CODEX_NON_INTERACTIVE=1 \
      CODEX_RELEASE="${CODEX_RELEASE}" \
      sh \
  && codex --version \
  && npm install -g opencode-ai \
  && npm install -g @anthropic-ai/claude-code \
  && npm install -g @githubnext/github-copilot-cli \
  && { bash -c "$(curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh)" -s --source qwenchat || true; } \
  && go install github.com/router-for-me/CLIProxyAPI/v6/cmd/server@latest \
  && mv /root/go/bin/server /usr/local/bin/CLIProxyAPI \
  && curl -fsLS https://raw.githubusercontent.com/twpayne/chezmoi/master/assets/scripts/install.sh | sh -s -- -b /usr/local/bin \
  && git clone --depth 1 --branch "${FLUTTER_CHANNEL}" https://github.com/flutter/flutter.git /opt/flutter \
  && chown -R "${USER_UID}:${USER_GID}" /opt/flutter

# Jules CLI is intentionally disabled. Its npm installer can preserve high
# UID/GID values from its downloaded payload, which makes the resulting image
# impossible to unpack with a normal rootless Podman subordinate-ID range.
# If Jules is re-enabled, normalize the installed payload ownership as part of
# the same layer so those archive owners are not published in the image.
# RUN set -euxo pipefail \
#   && npm install -g @google/jules \
#   && chown -h root:root /usr/local/bin/jules \
#   && chown -R root:root "$(npm root -g)/@google/jules" \
#   && jules version

ENV PATH=/opt/flutter/bin:/home/${USER_NAME}/.local/bin:${PATH}

COPY --chown=${USER_UID}:${USER_GID} --from=dotfiles . /tmp/dotfiles

COPY --chmod=0755 containers/dev-dotfiles-debian/entrypoint.sh /usr/local/bin/dev-dotfiles-entrypoint

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

# Use Google's canonical installer invocation. It installs agy to ~/.local/bin,
# which is already on PATH for the image user.
RUN set -euxo pipefail \
  && curl -fsSL https://antigravity.google/cli/install.sh | bash \
  && agy --version \
  && { yes "" | sh -c "chezmoi init --source /tmp/dotfiles --apply --force --no-tty --debug " || true; } \
  && rm -rf /tmp/dotfiles \
  && flutter --version \
  && go version \
  && git --version \
  && codex --version \
  && agy --version \
  && /usr/bin/zsh -l -c 'set -e; command -v agy; command -v codex; command -v flutter; case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "login PATH is missing $HOME/.local/bin" >&2; exit 1 ;; esac' \
  && curl -fsSL https://junie.jetbrains.com/install.sh | bash \
  && junie --version \
  && echo "dev-dotfiles-debian release: ${DOTFILES_RELEASE} (commit ${DOTFILES_COMMIT})" > /etc/motd

ENTRYPOINT ["/usr/local/bin/dev-dotfiles-entrypoint"]
