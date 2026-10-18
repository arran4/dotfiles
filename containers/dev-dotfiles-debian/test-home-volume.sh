#!/bin/sh
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
seed_script="$here/home-volume-seed.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/seed/.config" "$tmp/home/.config/gh" "$tmp/workspace"
printf 'image config v1\n' > "$tmp/seed/.config/example"
printf 'initial history\n' > "$tmp/seed/.zsh_history"
printf 'old config\n' > "$tmp/home/.config/example"
printf 'keep this\n' > "$tmp/home/only-in-volume"
printf 'runtime token\n' > "$tmp/home/.config/gh/hosts.yml"
printf 'existing checkout\n' > "$tmp/workspace/README"
printf 'image-v1:sha256-v1\n' > "$tmp/version"
tar -C "$tmp/seed" -cf "$tmp/seed.tar" .

seed_home() {
  HOME="$tmp/home" DEV_HOME_VOLUME_INIT=1 \
    DEV_HOME_SEED_ARCHIVE="$tmp/seed.tar" \
    DEV_HOME_SEED_VERSION_FILE="$tmp/version" sh "$seed_script"
}

if HOME="$tmp/home" DEV_HOME_SEED_ARCHIVE="$tmp/seed.tar" \
  DEV_HOME_SEED_VERSION_FILE="$tmp/version" \
  sh "$seed_script" > "$tmp/no-opt-in.log" 2>&1; then
  echo 'Seeding unexpectedly succeeded without opt-in' >&2
  exit 1
fi

# First start overlays matching seed files, but leaves volume-only data and
# the independent workspace alone.
seed_home
test "$(cat "$tmp/home/.config/example")" = 'image config v1'
test "$(cat "$tmp/home/only-in-volume")" = 'keep this'
test "$(cat "$tmp/home/.config/gh/hosts.yml")" = 'runtime token'
test "$(cat "$tmp/home/.zsh_history")" = 'initial history'
test "$(cat "$tmp/workspace/README")" = 'existing checkout'
test "$(cat "$tmp/home/.dev-dotfiles-seed-version")" = 'image-v1:sha256-v1'

# Same-version restarts do not replace user edits.
printf 'user config\n' > "$tmp/home/.config/example"
printf 'user history\n' > "$tmp/home/.zsh_history"
seed_home
test "$(cat "$tmp/home/.config/example")" = 'user config'
test "$(cat "$tmp/home/.zsh_history")" = 'user history'

# Updating the archive and version overlays matching config paths without
# deleting volume-only paths, runtime auth, shell history or the workspace.
printf 'image config v2\n' > "$tmp/seed/.config/example"
printf 'new image history\n' > "$tmp/seed/.zsh_history"
mkdir -p "$tmp/seed/.config/gh"
printf 'build-time auth placeholder\n' > "$tmp/seed/.config/gh/hosts.yml"
tar -C "$tmp/seed" -cf "$tmp/seed.tar" .
printf 'image-v2:sha256-v2\n' > "$tmp/version"
seed_home
test "$(cat "$tmp/home/.config/example")" = 'image config v2'
test "$(cat "$tmp/home/only-in-volume")" = 'keep this'
test "$(cat "$tmp/home/.config/gh/hosts.yml")" = 'runtime token'
test "$(cat "$tmp/home/.zsh_history")" = 'user history'
test "$(cat "$tmp/workspace/README")" = 'existing checkout'
test "$(cat "$tmp/home/.dev-dotfiles-seed-version")" = 'image-v2:sha256-v2'

# A missing archive must not advance the version. Restoring it retries the
# pending upgrade rather than considering a failed upgrade complete.
printf 'image-v3:sha256-v3\n' > "$tmp/version"
mv "$tmp/seed.tar" "$tmp/seed.backup.tar"
if seed_home > "$tmp/missing-archive.log" 2>&1; then
  echo 'Seeding unexpectedly succeeded with a missing archive' >&2
  exit 1
fi
test "$(cat "$tmp/home/.dev-dotfiles-seed-version")" = 'image-v2:sha256-v2'
mv "$tmp/seed.backup.tar" "$tmp/seed.tar"
seed_home
test "$(cat "$tmp/home/.dev-dotfiles-seed-version")" = 'image-v3:sha256-v3'

# Migrate known Antigravity files to the real ~/.gemini tree, including a
# recoverable token, without overwriting user state or removing unknown files.
migration="$here/migrate-antigravity-state.sh"
legacy_home="$tmp/migrate-home"
mkdir -p "$legacy_home/.codex/antigravity-cli/cache"
printf 'old settings\n' > "$legacy_home/.codex/antigravity-cli/settings.json"
printf 'old onboarding\n' > "$legacy_home/.codex/antigravity-cli/cache/onboarding.json"
printf 'old token\n' > "$legacy_home/.codex/antigravity-cli/antigravity-oauth-token"
HOME="$legacy_home" sh "$migration"
test "$(cat "$legacy_home/.gemini/antigravity-cli/settings.json")" = 'old settings'
test "$(cat "$legacy_home/.gemini/antigravity-cli/cache/onboarding.json")" = 'old onboarding'
test "$(cat "$legacy_home/.gemini/antigravity-cli/antigravity-oauth-token")" = 'old token'
test ! -e "$legacy_home/.codex/antigravity-cli"
test "$(stat -c %a "$legacy_home/.gemini/antigravity-cli/antigravity-oauth-token")" = 600
HOME="$legacy_home" sh "$migration"

# Preserve differing existing destinations and unrelated legacy state; clean
# an identical duplicate. Never follow a symlinked cache or token.
mkdir -p "$legacy_home/.codex/antigravity-cli/cache"
printf 'old settings\n' > "$legacy_home/.codex/antigravity-cli/settings.json"
printf 'legacy token\n' > "$legacy_home/.codex/antigravity-cli/antigravity-oauth-token"
printf 'old onboarding\n' > "$legacy_home/.codex/antigravity-cli/cache/onboarding.json"
printf 'unrelated\n' > "$legacy_home/.codex/antigravity-cli/other-file"
printf 'custom settings\n' > "$legacy_home/.gemini/antigravity-cli/settings.json"
HOME="$legacy_home" sh "$migration"
test "$(cat "$legacy_home/.gemini/antigravity-cli/settings.json")" = 'custom settings'
test "$(cat "$legacy_home/.codex/antigravity-cli/settings.json")" = 'old settings'
test "$(cat "$legacy_home/.gemini/antigravity-cli/antigravity-oauth-token")" = 'old token'
test "$(cat "$legacy_home/.codex/antigravity-cli/antigravity-oauth-token")" = 'legacy token'
test ! -e "$legacy_home/.codex/antigravity-cli/cache/onboarding.json"
test -f "$legacy_home/.codex/antigravity-cli/other-file"

# A symlinked source or destination subtree is never traversed.
mkdir -p "$tmp/outside" "$tmp/migrate-linked/.codex/antigravity-cli"
ln -s "$tmp/outside" "$tmp/migrate-linked/.gemini"
printf 'external settings\n' > "$tmp/outside/settings.json"
printf 'legacy settings\n' > "$tmp/migrate-linked/.codex/antigravity-cli/settings.json"
HOME="$tmp/migrate-linked" sh "$migration"
test -f "$tmp/migrate-linked/.codex/antigravity-cli/settings.json"
test "$(cat "$tmp/outside/settings.json")" = 'external settings'

echo 'Home volume seed and Antigravity migration tests passed.'
