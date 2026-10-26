#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
script="$repo_root/containers/dev-dotfiles-debian/sync-agent-skills.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
export DEV_SKILLS_SOURCE="$tmp/source"
export DEV_AGY_SKILLS_HOME="$tmp/home/skills"
export DEV_SKILLS_STATE_DIR="$tmp/state"
mkdir -p "$DEV_SKILLS_SOURCE/arran-test"
printf '%s\n' '---' 'name: arran-test' 'description: test' '---' '# v1' > "$DEV_SKILLS_SOURCE/arran-test/SKILL.md"
sh "$script"
cmp "$DEV_SKILLS_SOURCE/arran-test/SKILL.md" "$DEV_AGY_SKILLS_HOME/arran-test/SKILL.md"
test -f "$DEV_SKILLS_STATE_DIR/arran-test.sha256"
printf '\n# v2\n' >> "$DEV_SKILLS_SOURCE/arran-test/SKILL.md"
sh "$script"
cmp "$DEV_SKILLS_SOURCE/arran-test/SKILL.md" "$DEV_AGY_SKILLS_HOME/arran-test/SKILL.md"
printf '\n# user edit\n' >> "$DEV_AGY_SKILLS_HOME/arran-test/SKILL.md"
printf '\n# v3\n' >> "$DEV_SKILLS_SOURCE/arran-test/SKILL.md"
sh "$script"
grep -Fqx '# user edit' "$DEV_AGY_SKILLS_HOME/arran-test/SKILL.md"
! grep -Fqx '# v3' "$DEV_AGY_SKILLS_HOME/arran-test/SKILL.md"
mkdir -p "$DEV_AGY_SKILLS_HOME/other" "$DEV_SKILLS_SOURCE/other"
printf 'user\n' > "$DEV_AGY_SKILLS_HOME/other/SKILL.md"
printf 'image\n' > "$DEV_SKILLS_SOURCE/other/SKILL.md"
sh "$script"
grep -Fqx user "$DEV_AGY_SKILLS_HOME/other/SKILL.md"
echo 'Managed agent skill sync tests passed.'
