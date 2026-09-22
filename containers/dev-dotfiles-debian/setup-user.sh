#!/usr/bin/env bash
# Runs during the image build as the non-root image user.
set -euxo pipefail
# Keep the failing command and line visible without inheriting the trap into
# command substitutions (where a single failure would be reported repeatedly).
trap 'printf "setup-user.sh:%s: command failed (exit %s): %s\n" "$LINENO" "$?" "$BASH_COMMAND" >&2' ERR

curl -fsSL https://antigravity.google/cli/install.sh | bash
agy --version

# The endless yes process may exit with SIGPIPE once chezmoi finishes reading.
# Preserve chezmoi's exit status without treating yes's SIGPIPE as a failure.
set +o pipefail
yes "" | sh -c 'chezmoi init --source /tmp/dotfiles --apply --force --no-tty --debug'
set -o pipefail

rm -f "$HOME/.codex/hooks.json"
mkdir -p "$HOME/.codex"
if [[ ! -e "$HOME/.codex/config.toml" ]]; then
  config_source=/usr/local/share/dev-dotfiles-debian/codex-config.toml
  if [[ ! -r "$config_source" ]]; then
    printf 'Codex config is not readable by %s: %s\n' "$(id -un)" "$config_source" >&2
    ls -ld /usr/local/share /usr/local/share/dev-dotfiles-debian "$config_source" >&2 || true
    exit 1
  fi
  cp "$config_source" "$HOME/.codex/config.toml"
fi
rm -rf /tmp/dotfiles

flutter --version
go version
git --version
docker --version
docker buildx version
docker compose version
codex --version
agy --version
/usr/bin/zsh -l -c 'set -e; command -v agy; command -v codex; command -v flutter; command -v docker; command -v dockerd; case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "login PATH is missing $HOME/.local/bin" >&2; exit 1 ;; esac'

curl -fsSL https://junie.jetbrains.com/install.sh | bash
junie --version
{
  echo "dev-dotfiles-debian release: ${DOTFILES_RELEASE} (commit ${DOTFILES_COMMIT})"
  echo ""
  echo "Installed AI Agents & Tools:"
  echo "- Codex: $(codex --version 2>/dev/null || echo 'Unknown')"
  echo "- Antigravity: $(agy --version 2>/dev/null || echo 'Unknown')"
  # Do not exit awk early: pip must finish writing to avoid SIGPIPE under pipefail.
  MINI_SWE_VERSION=$(python3 -m pip show mini-swe-agent 2>/dev/null | awk '/^Version:/ {print $2}')
  echo "- Mini SWE Agent: ${MINI_SWE_VERSION:-Unknown}"
  echo "- OpenCode AI: $(opencode --version 2>/dev/null || echo 'Unknown')"
  echo "- Claude Code: $(claude --version 2>/dev/null || echo 'Unknown')"
  echo "- GitHub Copilot CLI: $(github-copilot-cli --version 2>/dev/null || echo 'Unknown')"
  echo "- QwenChat: $(jq -r '.version // empty' /usr/local/lib/qwen-code/manifest.json 2>/dev/null || npm list -g @qwen-code/qwen-code | grep @qwen-code/qwen-code@ | sed 's/.*@//' 2>/dev/null || echo 'Unknown')"
  echo "- Flutter: $(flutter --version 2>/dev/null | awk 'NR == 1 {print}' || echo 'Unknown')"
  echo "- Go: $(go version 2>/dev/null || echo 'Unknown')"
  echo "- Git: $(git --version 2>/dev/null || echo 'Unknown')"
  echo "- Docker: $(docker --version 2>/dev/null || echo 'Unknown')"
  echo "- Junie: $(junie --version 2>/dev/null || echo 'Unknown')"
} | sudo tee /etc/motd > /dev/null

{
  echo "codex --dangerously-bypass-approvals-and-sandbox"
  echo "agy --dangerously-skip-permissions"
  echo "mini --yolo"
  echo "opencode"
  echo "opencode --auto"
  echo "claude --dangerously-skip-permissions"
  echo "github-copilot-cli"
  echo "qwen --approval-mode yolo"
  echo "junie"
  echo "curl -fsS http://host.docker.internal:11434/v1/models | jq ."
  echo "gh auth login -h github.com -w -p https"
  echo "gh auth refresh -h github.com"
  echo "glab auth login --hostname gitlab.com"
} >> "/home/${USER_NAME}/.bash_history"
cp "/home/${USER_NAME}/.bash_history" "/home/${USER_NAME}/.zsh_history"

/usr/bin/zsh -l -c 'set -e;
  echo "Running smoke tests...";
  command -v codex >/dev/null || { echo "codex missing"; false; };
  command -v agy >/dev/null || { echo "agy missing"; false; };
  command -v opencode >/dev/null || { echo "opencode missing"; false; };
  command -v claude >/dev/null || { echo "claude missing"; false; };
  command -v github-copilot-cli >/dev/null || { echo "github-copilot-cli missing"; false; };
  command -v qwen >/dev/null || { echo "qwen missing"; false; };
  command -v mini >/dev/null || { echo "mini missing"; false; };
  command -v junie >/dev/null || { echo "junie missing"; false; };
  for tool in rg grep sed awk find xargs fd bat jq yq xq tomlq xmlstarlet xmllint shellcheck shfmt sponge patch rsync file tar zip unzip dos2unix envsubst ps pgrep pkill lsof strace ip ss ping nc socat openssl traceroute git-lfs; do
    command -v "$tool" >/dev/null || { echo "$tool missing"; false; };
  done;
  command -v less >/dev/null || { echo "less missing"; false; };
  command -v delta >/dev/null || { echo "delta missing"; false; };
  command -v nvim >/dev/null || { echo "nvim missing"; false; };
  command -v fish >/dev/null || { echo "fish missing"; false; };
  command -v btop >/dev/null || { echo "btop missing"; false; };
  command -v mvn >/dev/null || { echo "mvn missing"; false; };
  command -v dig >/dev/null || { echo "dig missing"; false; };
  command -v 7z >/dev/null || { echo "7z missing"; false; };
  command -v uprecords >/dev/null || { echo "uprecords missing"; false; };
  command -v git-credential-oauth >/dev/null || { echo "git-credential-oauth missing"; false; };
  command -v docker >/dev/null || { echo "docker missing"; false; };
  command -v dockerd >/dev/null || { echo "dockerd missing"; false; };
  docker buildx version >/dev/null || { echo "docker buildx unavailable"; false; };
  docker compose version >/dev/null || { echo "docker compose unavailable"; false; };
  python3 -m pip show mini-swe-agent >/dev/null || { echo "mini-swe-agent version check failed"; false; };
  opencode --version >/dev/null || { echo "opencode version check failed"; false; };
  case "$(opencode --help 2>&1)" in *--auto*) ;; *) echo "opencode --auto unavailable"; false;; esac;
  case "$(claude --help 2>&1)" in *--dangerously-skip-permissions*) ;; *) echo "claude sandbox launch flag unavailable"; false;; esac;
  case "$(qwen --help 2>&1)" in *--approval-mode*) ;; *) echo "qwen approval mode unavailable"; false;; esac;
  test "${LESS:-}" = "-R" || { echo "LESS is not configured for ANSI passthrough"; false; };
  pager="$(git config --global --get core.pager)";
  delta_path="$(command -v delta)";
  test "$(readlink -f "$pager")" = "$(readlink -f "$delta_path")" || { echo "git core.pager is not delta: $pager != $delta_path"; false; };
  git config --global --get-all credential.helper | grep -Eq "oauth( -device)?$" || { echo "git credential helper is not using OAuth"; false; };
  for history_file in ~/.bash_history ~/.zsh_history; do
    grep -Fqx "codex --dangerously-bypass-approvals-and-sandbox" "$history_file" || { echo "codex sandbox command missing from $history_file"; false; };
    grep -Fqx "opencode --auto" "$history_file" || { echo "opencode sandbox command missing from $history_file"; false; };
    grep -Fqx "claude --dangerously-skip-permissions" "$history_file" || { echo "claude sandbox command missing from $history_file"; false; };
    grep -Fqx "qwen --approval-mode yolo" "$history_file" || { echo "qwen approval mode command missing from $history_file"; false; };
    grep -Fqx "junie" "$history_file" || { echo "Junie command missing from $history_file"; false; };
    grep -Fqx "curl -fsS http://host.docker.internal:11434/v1/models | jq ." "$history_file" || { echo "Ollama check missing from $history_file"; false; };
    grep -Fqx "gh auth login -h github.com -w -p https" "$history_file" || { echo "GitHub auth command missing from $history_file"; false; };
    grep -Fqx "gh auth refresh -h github.com" "$history_file" || { echo "GitHub auth refresh command missing from $history_file"; false; };
    grep -Fqx "glab auth login --hostname gitlab.com" "$history_file" || { echo "GitLab auth command missing from $history_file"; false; };
  done;
  echo "Smoke tests passed."'

# The image build has no credentials, but authentication failures can have
# different diagnostic wording (for example when the API is unavailable).
# Assert observable behaviour rather than matching one obsolete help sentence.
entry_output=$(/usr/local/bin/dev-dotfiles-entrypoint -c "echo 'Entrypoint ran'" 2>&1)
if ! grep -Fq "Checking GitHub CLI authentication status..." <<< "$entry_output"; then
  echo "Entrypoint failed to run auth status check"
  echo "$entry_output"
  exit 1
fi
if ! grep -Fq "Not authenticated with GitHub CLI." <<< "$entry_output" &&
   ! grep -Fq "GitHub CLI could not verify authentication" <<< "$entry_output"; then
  echo "Entrypoint did not provide unauthenticated GitHub CLI guidance"
  echo "$entry_output"
  exit 1
fi
if ! grep -Fxq "Entrypoint ran" <<< "$entry_output"; then
  echo "Entrypoint did not continue after auth status check"
  echo "$entry_output"
  exit 1
fi
