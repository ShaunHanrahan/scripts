#!/bin/bash

# Ensure git and jq are installed
if ! [ -x "$(command -v git)" ] || ! [ -x "$(command -v jq)" ]; then
  echo "Error: git and jq are required." >&2
  exit 1
fi

# Check for username argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <github_username>"
    exit 1
fi

USERNAME=$1
TARGET_DIR="$HOME/code/$USERNAME"
API_URL="https://api.github.com/users/$USERNAME/repos?per_page=100"

# Create the directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Fetch the repo list from GitHub, sort them by size in descending order, and then clone each repo
curl -s "$API_URL" | jq -r ".[] | select(.fork == false) | .size, .clone_url" | while read -r SIZE; read -r REPO; do
    REPO_NAME=$(echo "$REPO" | awk -F'/' '{print $NF}' | sed 's/.git//')
    if [ ! -d "$TARGET_DIR/$REPO_NAME" ]; then
        echo "Cloning $REPO_NAME of size $SIZE KB..."
        git clone "$REPO" "$TARGET_DIR/$REPO_NAME"
    else
        echo "$REPO_NAME already exists. Skipping..."
    fi
done | sort -rn

echo "All repositories cloned to $TARGET_DIR."

