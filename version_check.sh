#!/bin/bash

# GitHub API URL for Meowcoin releases
GITHUB_API="https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest"

# Get the current version from our file
CURRENT_VERSION=$(cat meowcoin_version.txt)

# Get the latest version from GitHub
LATEST_VERSION=$(curl -s $GITHUB_API | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# If GitHub API rate limit is hit or connection issue
if [ -z "$LATEST_VERSION" ]; then
  echo "Error: Could not fetch latest version from GitHub API"
  exit 1
fi

# Compare versions
if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
  echo "New version available: $LATEST_VERSION (current: $CURRENT_VERSION)"
  echo "$LATEST_VERSION" > meowcoin_version.txt
  
  # Configure git
  git config --global user.name "GitHub Actions Bot"
  git config --global user.email "actions@github.com"
  
  # Commit and push changes
  git add meowcoin_version.txt
  git commit -m "Update Meowcoin to version $LATEST_VERSION [skip ci]"
  git push
  
  echo "Version updated to $LATEST_VERSION"
  exit 0
else
  echo "Already using the latest version: $CURRENT_VERSION"
  exit 1  # Non-zero exit for "no change" to control workflow
fi