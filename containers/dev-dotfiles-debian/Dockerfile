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
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  jq \
  gh \
  git \
  git-credential-oauth \
  openssh-client \
  sudo \
  zsh \
  fish \
  atuin \
  vim \
  neovim \
  less \
  git-delta \
  kdiff3 \
  diffutils \
  ripgrep \
  fd-find \
  fzf \
  tmux \
  htop \
  btop \
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
  maven \
  nodejs \
  unzip \
  7zip \
  bind9-dnsutils \
  uptimed \
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

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

# Tools that influence rendered dotfiles (for example delta, nvim, less,
# git-credential-oauth and atuin) are installed above before this apply step.
# This ensures chezmoi renders the same integrations the image will actually use.
# Use Google's canonical installer invocation. It installs agy to ~/.local/bin,
# which is already on PATH for the image user.
RUN set -euxo pipefail \
  && curl -fsSL https://antigravity.google/cli/install.sh | bash \
  && agy --version \
  && set +o pipefail \
  && yes "" | sh -c "chezmoi init --source /tmp/dotfiles --apply --force --no-tty --debug " \
  && set -o pipefail \
  && rm -rf /tmp/dotfiles \
  && flutter --version \
  && go version \
  && git --version \
  && codex --version \
  && agy --version \
  && /usr/bin/zsh -l -c 'set -e; command -v agy; command -v codex; command -v flutter; case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "login PATH is missing $HOME/.local/bin" >&2; exit 1 ;; esac' \
  && curl -fsSL https://junie.jetbrains.com/install.sh | bash \
  && junie --version \
  && { \
    echo "dev-dotfiles-debian release: ${DOTFILES_RELEASE} (commit ${DOTFILES_COMMIT})"; \
    echo ""; \
    echo "Installed AI Agents & Tools:"; \
    echo "- Codex: $(codex --version 2>/dev/null || echo 'Unknown')"; \
    echo "- Antigravity: $(agy --version 2>/dev/null || echo 'Unknown')"; \
    MINI_SWE_VERSION=$(python3 -m pip show mini-swe-agent 2>/dev/null | awk '/^Version:/{print $2; exit}'); \
    echo "- Mini SWE Agent: ${MINI_SWE_VERSION:-Unknown}"; \
    echo "- OpenCode AI: $(opencode --version 2>/dev/null || echo 'Unknown')"; \
    echo "- Claude Code: $(claude --version 2>/dev/null || echo 'Unknown')"; \
    echo "- GitHub Copilot CLI: $(github-copilot-cli --version 2>/dev/null || echo 'Unknown')"; \
    echo "- QwenChat: $(jq -r '.version // empty' /usr/local/lib/qwen-code/manifest.json 2>/dev/null || npm list -g @qwen-code/qwen-code | grep @qwen-code/qwen-code@ | sed 's/.*@//' 2>/dev/null || echo 'Unknown')"; \
    echo "- Flutter: $(flutter --version 2>/dev/null | head -n 1 || echo 'Unknown')"; \
    echo "- Go: $(go version 2>/dev/null || echo 'Unknown')"; \
    echo "- Git: $(git --version 2>/dev/null || echo 'Unknown')"; \
    echo "- Junie: $(junie --version 2>/dev/null || echo 'Unknown')"; \
  } | sudo tee /etc/motd > /dev/null \
  && { \
    echo "codex --dangerously-bypass-approvals-and-sandbox"; \
    echo "agy --dangerously-skip-permissions"; \
    echo "mini --yolo"; \
    echo "opencode"; \
    echo "claude"; \
    echo "github-copilot-cli"; \
    echo "qwen"; \
  } > /home/${USER_NAME}/.bash_history \
  && cp /home/${USER_NAME}/.bash_history /home/${USER_NAME}/.zsh_history \
  && /usr/bin/zsh -l -c 'set -e; \
     echo "Running smoke tests..."; \
     command -v codex >/dev/null || { echo "codex missing"; false; }; \
     command -v agy >/dev/null || { echo "agy missing"; false; }; \
     command -v opencode >/dev/null || { echo "opencode missing"; false; }; \
     command -v claude >/dev/null || { echo "claude missing"; false; }; \
     command -v github-copilot-cli >/dev/null || { echo "github-copilot-cli missing"; false; }; \
     command -v qwen >/dev/null || { echo "qwen missing"; false; }; \
     command -v mini >/dev/null || { echo "mini missing"; false; }; \
     command -v less >/dev/null || { echo "less missing"; false; }; \
     command -v delta >/dev/null || { echo "delta missing"; false; }; \
     command -v nvim >/dev/null || { echo "nvim missing"; false; }; \
     command -v atuin >/dev/null || { echo "atuin missing"; false; }; \
     command -v fish >/dev/null || { echo "fish missing"; false; }; \
     command -v btop >/dev/null || { echo "btop missing"; false; }; \
     command -v mvn >/dev/null || { echo "mvn missing"; false; }; \
     command -v dig >/dev/null || { echo "dig missing"; false; }; \
     command -v 7z >/dev/null || { echo "7z missing"; false; }; \
     command -v uprecords >/dev/null || { echo "uprecords missing"; false; }; \
     command -v git-credential-oauth >/dev/null || { echo "git-credential-oauth missing"; false; }; \
     python3 -m pip show mini-swe-agent >/dev/null || { echo "mini-swe-agent version check failed"; false; }; \
     opencode --version >/dev/null || { echo "opencode version check failed"; false; }; \
     test "${LESS:-}" = "-R" || { echo "LESS is not configured for ANSI passthrough"; false; }; \
     test "$(git config --global --get core.pager)" = "$(command -v delta)" || { echo "git core.pager is not delta"; false; }; \
     git config --global --get-all credential.helper | grep -Eq "oauth( -device)?$" || { echo "git credential helper is not using OAuth"; false; }; \
     grep -q "atuin" "$HOME/.zshrc" || { echo "atuin shell integration was not rendered"; false; }; \
     echo "Smoke tests passed."'

ENTRYPOINT ["/usr/local/bin/dev-dotfiles-entrypoint"]
