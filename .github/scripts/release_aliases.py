#!/usr/bin/env python3
"""Select monotonic GHCR moving aliases for a stable Git tag.

Run inside the serialized image-alias publication job, immediately before pushing.
The only source of truth is the repository's remote Git tags.
"""

import re
import subprocess
import sys

STABLE_TAG = re.compile(r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")


def parse_stable(tag):
    match = STABLE_TAG.fullmatch(tag)
    return tuple(map(int, match.groups())) if match else None


def tags_from_ls_remote(output):
    tags = []
    for line in output.splitlines():
        _, separator, ref = line.partition("\t")
        if not separator or not ref.startswith("refs/tags/"):
            raise ValueError("unexpected git ls-remote output")
        if not ref.endswith("^{}"):
            tags.append(ref.removeprefix("refs/tags/"))
    return tags


def moving_aliases(release_tag, remote_tags):
    version = parse_stable(release_tag)
    if version is None:
        return []  # Never move stable aliases for prereleases or test tags.

    stable_versions = {value for tag in remote_tags if (value := parse_stable(tag)) is not None}
    if version not in stable_versions:
        raise ValueError(f"release tag {release_tag} is absent from remote tags")

    major, minor, _ = version
    aliases = []
    if version == max(v for v in stable_versions if v[:2] == (major, minor)):
        aliases.append(f"v{major}.{minor}")
    if version == max(v for v in stable_versions if v[0] == major):
        aliases.append(f"v{major}")
    if version == max(stable_versions):
        aliases.append("latest")
    return aliases


def main():
    if len(sys.argv) != 2:
        raise ValueError("expected exactly one Git release tag")
    release_tag = sys.argv[1]
    if parse_stable(release_tag) is None:
        return  # Nothing to publish for prerelease/test tags.
    response = subprocess.run(
        ["git", "ls-remote", "--tags", "origin"],
        check=True, capture_output=True, text=True,
    )
    for alias in moving_aliases(release_tag, tags_from_ls_remote(response.stdout)):
        print(alias)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Refusing moving-alias update: {error}", file=sys.stderr)
        sys.exit(1)
