#!/bin/sh
set -eu
repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
script="$repo_root/containers/dev-dotfiles-debian/sync-agent-plugins.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

export DEV_PLUGINS_SOURCE="$tmp/source"
export DEV_AGY_PLUGINS_HOME="$tmp/home/config/plugins"
export DEV_PLUGINS_STATE_DIR="$tmp/state/plugins"
export DEV_AGY_SKILLS_HOME="$tmp/home/legacy-skills"
export DEV_SKILLS_STATE_DIR="$tmp/state/legacy-skills"
mkdir -p "$DEV_PLUGINS_SOURCE" "$DEV_AGY_SKILLS_HOME" "$DEV_SKILLS_STATE_DIR"
cp -R "$repo_root/containers/dev-dotfiles-debian/agent-plugins/." "$DEV_PLUGINS_SOURCE/"

# Check the portable manifest, skill discovery layout and exact migration
# content without requiring the Antigravity binary on GitHub-hosted runners.
python3 - "$DEV_PLUGINS_SOURCE" "$repo_root" <<'PY'
import json
from pathlib import Path
import sys

source, root = map(Path, sys.argv[1:])
for directory in source.iterdir():
    if not directory.is_dir():
        continue
    manifest = json.loads((directory / "plugin.json").read_text())
    assert manifest["$schema"] == "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
    assert manifest["name"] == directory.name
    assert manifest["version"]
    skills = list((directory / "skills").glob("*/SKILL.md"))
    assert skills, directory
    for skill in skills:
        lines = skill.read_text().splitlines()
        assert lines[0] == "---"
        assert f"name: {skill.parent.name}" in lines
assert (source / "arran4-gosubc/skills/gosubc/SKILL.md").is_file()
assert not (root / "containers/dev-dotfiles-debian/agent-skills/gosubc/SKILL.md").exists()
PY

plugin="arran4-gosubc"
skill="skills/gosubc/SKILL.md"
destination="$DEV_AGY_PLUGINS_HOME/$plugin"
state="$DEV_PLUGINS_STATE_DIR/$plugin.sha256"

sh "$script"
cmp "$DEV_PLUGINS_SOURCE/$plugin/$skill" "$destination/$skill"
test -f "$state"

# Image changes update unmodified plugins.
printf '\n# image v2\n' >> "$DEV_PLUGINS_SOURCE/$plugin/$skill"
sh "$script"
cmp "$DEV_PLUGINS_SOURCE/$plugin/$skill" "$destination/$skill"

# Locally modified plugins survive a later image update.
printf '\n# user edit\n' >> "$destination/$skill"
printf '\n# image v3\n' >> "$DEV_PLUGINS_SOURCE/$plugin/$skill"
sh "$script"
grep -Fqx '# user edit' "$destination/$skill"
if grep -Fqx '# image v3' "$destination/$skill"; then
  echo 'User-modified plugin was overwritten' >&2
  exit 1
fi

# Reinstall a clean managed copy to test legacy-skill retirement.
rm -rf -- "$destination"
rm -f -- "$state"
sh "$script"
cmp "$DEV_PLUGINS_SOURCE/$plugin/$skill" "$destination/$skill"

fingerprint() (
  cd "$1"
  find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -d ' ' -f 1
)
legacy="$DEV_AGY_SKILLS_HOME/gosubc"
legacy_state="$DEV_SKILLS_STATE_DIR/gosubc.sha256"
mkdir -p "$legacy"
printf 'managed legacy skill\n' > "$legacy/SKILL.md"
fingerprint "$legacy" > "$legacy_state"
sh "$script"
test ! -e "$legacy"
test ! -e "$legacy_state"

# Modified legacy skills are explicitly retained.
mkdir -p "$legacy"
printf 'managed legacy skill\n' > "$legacy/SKILL.md"
fingerprint "$legacy" > "$legacy_state"
printf 'user change\n' >> "$legacy/SKILL.md"
sh "$script"
grep -Fqx 'user change' "$legacy/SKILL.md"

# An untracked user plugin must never be replaced.
rm -rf -- "$destination"
rm -f -- "$state"
mkdir -p "$destination"
printf 'user plugin\n' > "$destination/README.md"
sh "$script"
grep -Fqx 'user plugin' "$destination/README.md"
test ! -e "$state"

echo 'Managed Antigravity plugin tests passed.'
