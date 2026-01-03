#!/bin/bash
set -e

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required tools
if ! command_exists gh; then
  echo "Error: 'gh' (GitHub CLI) is not installed."
  exit 1
fi

if ! command_exists git; then
  echo "Error: 'git' is not installed."
  exit 1
fi

# 1. Get Branch Name
read -r -e -p "Enter new branch name: " branch_name
if [ -z "$branch_name" ]; then
  echo "Error: Branch name is required."
  exit 1
fi

# 2. Get Commit Message
read -r -e -p "Enter commit message: " commit_message
if [ -z "$commit_message" ]; then
  echo "Error: Commit message is required."
  exit 1
fi

# 3. Get PR Title
read -r -e -p "Enter PR title (default: '$commit_message'): " pr_title
pr_title=${pr_title:-$commit_message}

# 4. Get PR Body
tmp_file=$(mktemp)
echo "# Enter PR description below. Save and quit to continue." > "$tmp_file"
echo "# Lines starting with '#' will be ignored." >> "$tmp_file"
echo "" >> "$tmp_file"

# Use EDITOR if set, otherwise vim
EDITOR="${EDITOR:-vim}"

# Verify editor exists
if ! command_exists "$EDITOR"; then
    echo "Error: Editor '$EDITOR' not found. Please set EDITOR environment variable or install vim."
    rm "$tmp_file"
    exit 1
fi

echo "Opening $EDITOR for PR description..."
$EDITOR "$tmp_file"

# Process the body file to remove comments
processed_body_file=$(mktemp)
grep -v '^#' "$tmp_file" > "$processed_body_file"

# 5. Confirm actions
echo ""
echo "=========================================="
echo "Summary of actions:"
echo "1. Create and switch to branch: $branch_name"
echo "2. Add all files (git add .)"
echo "3. Commit with message: '$commit_message'"
echo "4. Push branch to origin"
echo "5. Create PR with title: '$pr_title'"
echo "=========================================="
echo "PR Description preview:"
echo "------------------------------------------"
cat "$processed_body_file"
echo "------------------------------------------"
echo ""

read -r -e -p "Proceed? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  rm "$tmp_file" "$processed_body_file"
  exit 0
fi

# Execution
echo "Executing..."

# Create and checkout branch
if ! git checkout -b "$branch_name"; then
  echo "Error creating branch."
  rm "$tmp_file" "$processed_body_file"
  exit 1
fi

# Add and Commit
git add .
if ! git commit -m "$commit_message"; then
  echo "Error committing changes."
  rm "$tmp_file" "$processed_body_file"
  exit 1
fi

# Push
if ! git push -u origin "$branch_name"; then
  echo "Error pushing branch."
  rm "$tmp_file" "$processed_body_file"
  exit 1
fi

# Create PR
if ! gh pr create --title "$pr_title" --body-file "$processed_body_file"; then
  echo "Error creating PR."
  rm "$tmp_file" "$processed_body_file"
  exit 1
fi

echo "Success!"
rm "$tmp_file" "$processed_body_file"
