# Repo Guidelines for arran4/dotfiles

This repository stores dotfiles that are applied with [chezmoi](https://www.chezmoi.io/).

## Style
- Use **two spaces** for indentation and spaces over tabs.
- Ensure files end with a newline.
- Line endings must be LF.
- Trim trailing whitespace in all files except Markdown.

## Testing
Before submitting a pull request, attempt to apply the configuration using chezmoi:

```sh
yes "" | sh -c "$(curl -fsLS get.chezmoi.io)" -- init --no-tty --debug --apply arran4
```

If this command fails due to network restrictions, note this in the testing section of the PR.

## Pull Requests
Provide a concise summary of changes and cite any relevant files or lines.
