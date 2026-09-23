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

# Keep the expensive tool installation separate from the dotfiles-dependent
# home seed so changing dotfiles does not reinstall the entire toolchain.
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
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  jq \
  xmlstarlet \
  libxml2-utils \
  gh \
  git \
  git-lfs \
  git-credential-oauth \
  openssh-client \
  sudo \
  bash \
  bash-completion \
  zsh \
  fish \
  vim \
  neovim \
  less \
  bat \
  git-delta \
  kdiff3 \
  coreutils \
  grep \
  sed \
  gawk \
  findutils \
  diffutils \
  file \
  patch \
  rsync \
  moreutils \
  shellcheck \
  shfmt \
  ripgrep \
  fd-find \
  fzf \
  tmux \
  htop \
  btop \
  tree \
  procps \
  psmisc \
  lsof \
  strace \
  time \
  util-linux \
  bsdextrautils \
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
  maven \
  nodejs \
  docker.io \
  docker-cli \
  docker-buildx \
  docker-compose \
  tar \
  gzip \
  bzip2 \
  zip \
  unzip \
  7zip \
  xz-utils \
  dos2unix \
  gettext-base \
  iproute2 \
  iputils-ping \
  netcat-openbsd \
  socat \
  openssl \
  traceroute \
  bind9-dnsutils \
  uptimed \
  hugo \
  ca-certificates \
  locales \
  && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
  && ln -sf /usr/bin/batcat /usr/local/bin/bat \
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
  && python3 -m pip install --no-cache-dir --break-system-packages "mini-swe-agent" "yq" \
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
  && npm install -g @qwen-code/qwen-code \
  && GOBIN=/usr/local/bin go install github.com/router-for-me/CLIProxyAPI/v6/cmd/server@latest \
  && mv /usr/local/bin/server /usr/local/bin/CLIProxyAPI \
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
COPY containers/dev-dotfiles-debian/skel/ /usr/local/share/dev-dotfiles-debian/skel/
COPY --chmod=0644 containers/dev-dotfiles-debian/skel/.codex/config.toml /usr/local/share/dev-dotfiles-debian/codex-config.toml
COPY --chmod=0755 containers/dev-dotfiles-debian/setup-user.sh /usr/local/bin/dev-dotfiles-setup-user
COPY --chmod=0755 containers/dev-dotfiles-debian/home-volume-seed.sh /usr/local/bin/dev-dotfiles-home-seed

# Prepare the home as the non-root user, then archive and clear it as root in
# the SAME layer. This avoids a temporary full home in an intermediate image
# layer and avoids switching Dockerfile USER/WORKDIR for build-only operations.
# COPY can leave the config parent without directory search permission; fix it
# before running the user setup and verify access as the actual non-root user.
RUN set -eu; \
  home=$(getent passwd "$USER_NAME" | cut -d: -f6); \
  test -d "$home"; \
  install -d -m 0755 /usr/local/share/dev-dotfiles-debian; \
  runuser -u "$USER_NAME" -- test -r /usr/local/share/dev-dotfiles-debian/codex-config.toml; \
  runuser -u "$USER_NAME" -- sh -c 'cd "$HOME" && exec /usr/local/bin/dev-dotfiles-setup-user'; \
  test ! -L /workspace; \
  install -d -o "$(id -u "$USER_NAME")" -g "$(id -g "$USER_NAME")" /workspace; \
  if [ -d "$home/workspace" ] && [ ! -L "$home/workspace" ] && [ -z "$(ls -A "$home/workspace")" ]; then rmdir "$home/workspace"; fi; \
  if [ ! -e "$home/workspace" ] && [ ! -L "$home/workspace" ]; then ln -s /workspace "$home/workspace"; fi; \
  tar -C "$home" --exclude='./.codex/config.toml' --exclude='./.gemini/antigravity-cli/settings.json' -cf /usr/local/share/dev-dotfiles-debian/home-seed.tar .; \
  digest=$(sha256sum /usr/local/share/dev-dotfiles-debian/home-seed.tar | cut -d ' ' -f 1); \
  printf '%s:%s:%s\n' "$DOTFILES_RELEASE" "$DOTFILES_COMMIT" "$digest" > /usr/local/share/dev-dotfiles-debian/home-seed-version; \
  find "$home" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

ENV DEV_HOME_SEED_ARCHIVE=/usr/local/share/dev-dotfiles-debian/home-seed.tar \
  DEV_HOME_SEED_VERSION_FILE=/usr/local/share/dev-dotfiles-debian/home-seed-version
LABEL io.github.arran4.dev-dotfiles.home-seed="1"

USER ${USER_NAME}
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/dev-dotfiles-entrypoint"]
