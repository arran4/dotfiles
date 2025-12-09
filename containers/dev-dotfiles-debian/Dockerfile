# syntax=docker/dockerfile:1.7

ARG DEBIAN_RELEASE=stable
FROM debian:${DEBIAN_RELEASE}-slim

ARG USER_NAME=user
ARG USER_UID=1000
ARG USER_GID=1000
ARG GEMINI_CLI_PACKAGE=gemini-cli
ARG CODEX_CLI_PACKAGE=codex-cli
ARG FLUTTER_CHANNEL=stable

ENV DEBIAN_FRONTEND=noninteractive \
  TZ=Etc/UTC \
  SHELL=/usr/bin/zsh

RUN set -euxo pipefail \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  curl \
  wget \
  git \
  gnupg \
  gpg \
  gpg-agent \
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
  && rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=noninteractive

RUN set -euxo pipefail \
  && apt-get update \
  && apt-get install -y --no-install-recommends locales \
  && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
  && locale-gen

# Make UTF-8 the default for every process
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN set -euxo pipefail \
  && groupadd --gid "${USER_GID}" "${USER_NAME}" \
  && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /usr/bin/zsh "${USER_NAME}" \
  && mkdir -p /etc/sudoers.d \
  && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} \
  && chmod 0440 /etc/sudoers.d/${USER_NAME}

RUN set -euxo pipefail \
  && python3 -m pip install --no-cache-dir --break-system-packages \
    "${GEMINI_CLI_PACKAGE}" \
    "${CODEX_CLI_PACKAGE}"

RUN set -euxo pipefail \
  && npm install -g @google/jules

RUN set -euxo pipefail \
  && npm install -g opencode-ai

RUN set -euxo pipefail \
  && curl -fsLS https://raw.githubusercontent.com/twpayne/chezmoi/master/assets/scripts/install.sh | sh -s -- -b /usr/local/bin

RUN set -euxo pipefail \
  && git clone --depth 1 --branch "${FLUTTER_CHANNEL}" https://github.com/flutter/flutter.git /opt/flutter \
  && chown -R "${USER_UID}:${USER_GID}" /opt/flutter

ENV PATH=/opt/flutter/bin:/home/${USER_NAME}/.local/bin:${PATH}

COPY --from=dotfiles . /tmp/dotfiles
RUN set -euxo pipefail \
  && chown -R "${USER_UID}:${USER_GID}" /tmp/dotfiles

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

RUN yes "" | sh -c "chezmoi init --source /tmp/dotfiles --apply --force --no-tty --debug "; \
  rm -rf /tmp/dotfiles

RUN set -euxo pipefail \
  && flutter --version \
  && go version \
  && git --version

ENTRYPOINT ["/usr/bin/zsh", "-l"]
