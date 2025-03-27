#!/bin/bash

# GitHub API URL for Meowcoin releases
GITHUB_API="https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest"
# Use token to avoid rate limiting
GH_HEADER=""
if [ ! -z "$GITHUB_TOKEN" ]; then
  GH_HEADER="Authorization: token $GITHUB_TOKEN"
fi

# Get the current version from our file
CURRENT_VERSION=$(cat meowcoin_version.txt)

# Get the latest version from GitHub with rate limit handling
MAX_ATTEMPTS=3
ATTEMPT=1
LATEST_VERSION=""

while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ -z "$LATEST_VERSION" ]; do
  if [ -z "$GH_HEADER" ]; then
    RESPONSE=$(curl -s -H "Accept: application/vnd.github.v3+json" $GITHUB_API)
  else
    RESPONSE=$(curl -s -H "$GH_HEADER" -H "Accept: application/vnd.github.v3+json" $GITHUB_API)
  fi

  # Check for rate limit errors
  RATE_LIMITED=$(echo "$RESPONSE" | grep -c "rate limit exceeded")
  if [ $RATE_LIMITED -gt 0 ]; then
    echo "Rate limit exceeded. Attempt $ATTEMPT of $MAX_ATTEMPTS."
    sleep 10
    ATTEMPT=$((ATTEMPT+1))
    continue
  fi

  LATEST_VERSION=$(echo "$RESPONSE" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"\(.*\)"/\1/')
  
  if [ -z "$LATEST_VERSION" ]; then
    echo "Could not parse version. Attempt $ATTEMPT of $MAX_ATTEMPTS."
    sleep 5
    ATTEMPT=$((ATTEMPT+1))
  fi
done

# If all attempts failed
if [ -z "$LATEST_VERSION" ]; then
  echo "Error: Could not fetch latest version from GitHub API after $MAX_ATTEMPTS attempts"
  exit 1
fi

# Compare versions (semantic version comparison)
CURRENT_WITHOUT_PREFIX=${CURRENT_VERSION#Meow-v}
LATEST_WITHOUT_PREFIX=${LATEST_VERSION#Meow-v}

function version_gt() {
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

if version_gt "$LATEST_WITHOUT_PREFIX" "$CURRENT_WITHOUT_PREFIX"; then
  echo "New version available: $LATEST_VERSION (current: $CURRENT_VERSION)"
  echo "$LATEST_VERSION" > meowcoin_version.txt
  
  # Configure git
  git config --global user.name "GitHub Actions Bot"
  git config --global user.email "actions@github.com"
  
  # Commit and push changes
  git add meowcoin_version.txt
  git commit -m "Update Meowcoin to version $LATEST_VERSION [skip ci]"
  
  # Retry git push up to 3 times if it fails
  MAX_PUSH_ATTEMPTS=3
  PUSH_ATTEMPT=1
  PUSH_SUCCESS=false
  
  while [ $PUSH_ATTEMPT -le $MAX_PUSH_ATTEMPTS ] && [ "$PUSH_SUCCESS" = "false" ]; do
    if git push; then
      PUSH_SUCCESS=true
    else
      echo "Git push failed. Attempt $PUSH_ATTEMPT of $MAX_PUSH_ATTEMPTS."
      sleep 5
      PUSH_ATTEMPT=$((PUSH_ATTEMPT+1))
    fi
  done
  
  if [ "$PUSH_SUCCESS" = "false" ]; then
    echo "Error: Failed to push changes after $MAX_PUSH_ATTEMPTS attempts"
    exit 2
  fi
  
  echo "Version updated to $LATEST_VERSION"
  echo "::set-output name=new_version::$LATEST_VERSION"
  exit 0
else
  echo "Already using the latest version: $CURRENT_VERSION"
  exit 1  # Non-zero exit for "no change" to control workflow
fi