#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
git_template=home/dot_gitconfig.tmpl
ssh_template=home/private_dot_ssh/private_config.tmpl
installer=home/.chezmoiscripts/run_after_deploy-private-root-git.sh.tmpl
man=home/dot_local/share/man/man7/root-git-configuration.7

grep -Fq 'eq .chezmoi.username "root"' "$git_template"
grep -Fq 'interactive = false' "$git_template"
grep -Fq '/etc/gitconfig.d/{{ .chezmoi.hostname }}.conf' "$git_template"
grep -Fq 'Include /root/.ssh/config.d/*.conf' "$ssh_template"
grep -Fq 'identity=/root/.ssh/etckeeper_gitlab' "$installer"
test -s "$man"

# Render the one hostname placeholder without requiring root or a live overlay.
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
sed -e 's/{{ .chezmoi.hostname }}/test-host/g' "$installer" > "$temp/installer.sh"
sh -n "$temp/installer.sh"

# Prove repository-scoped pushurl overrides HTTPS only for /etc.
mkdir -p "$temp/etc/gitconfig.d" "$temp/other"
git init -q "$temp/etc"
git init -q "$temp/other"
git -C "$temp/etc" remote add origin https://gitlab.example.invalid/team/etc.git
git -C "$temp/other" remote add origin https://gitlab.example.invalid/team/other.git
printf '[remote "origin"]\n  pushurl = git@gitlab-etckeeper:team/etc.git\n' > "$temp/etc/gitconfig.d/host.etckeeper.conf"
printf '[includeIf "gitdir:%s/etc/"]\n  path = %s/etc/gitconfig.d/host.etckeeper.conf\n' "$temp" "$temp" > "$temp/root.gitconfig"
test "$(GIT_CONFIG_GLOBAL="$temp/root.gitconfig" git -C "$temp/etc" remote get-url --push origin)" = 'git@gitlab-etckeeper:team/etc.git'
test "$(GIT_CONFIG_GLOBAL="$temp/root.gitconfig" git -C "$temp/other" remote get-url --push origin)" = 'https://gitlab.example.invalid/team/other.git'
printf 'Headless root Git configuration contract: passed\n'
