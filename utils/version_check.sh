#!/bin/bash

# GitHub API URL for Meowcoin releases
GITHUB_API="https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest"
# Log file for debugging
LOG_FILE="version_check.log"

echo "Starting version check at $(date)" > $LOG_FILE

# Function to handle API errors
function handle_api_error() {
  local ERROR_CODE=$1
  local ERROR_MSG=$2
  
  echo "GitHub API error (${ERROR_CODE}): ${ERROR_MSG}" | tee -a $LOG_FILE
  
  case $ERROR_CODE in
    403)
      echo "Rate limit exceeded or access denied" | tee -a $LOG_FILE
      # Check rate limit information
      curl -s https://api.github.com/rate_limit | tee -a $LOG_FILE
      ;;
    404)
      echo "Repository or resource not found" | tee -a $LOG_FILE
      ;;
    *)
      echo "Unexpected error occurred" | tee -a $LOG_FILE
      ;;
  esac
}

# Use token to avoid rate limiting
GH_HEADER=""
if [ ! -z "$GITHUB_TOKEN" ]; then
  GH_HEADER="Authorization: token $GITHUB_TOKEN"
fi

# Get the current version from our file
if [ ! -f "meowcoin_version.txt" ]; then
  echo "Error: meowcoin_version.txt file not found" | tee -a $LOG_FILE
  exit 1
fi

CURRENT_VERSION=$(cat meowcoin_version.txt)
echo "Current version: $CURRENT_VERSION" | tee -a $LOG_FILE

# Get the latest version from GitHub with rate limit handling
MAX_ATTEMPTS=3
ATTEMPT=1
LATEST_VERSION=""

while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ -z "$LATEST_VERSION" ]; do
  echo "Fetching from GitHub API (attempt $ATTEMPT/$MAX_ATTEMPTS)" | tee -a $LOG_FILE
  
  if [ -z "$GH_HEADER" ]; then
    RESPONSE=$(curl -s -w "%{http_code}" -H "Accept: application/vnd.github.v3+json" $GITHUB_API -o /tmp/github_response.json)
  else
    RESPONSE=$(curl -s -w "%{http_code}" -H "$GH_HEADER" -H "Accept: application/vnd.github.v3+json" $GITHUB_API -o /tmp/github_response.json)
  fi
  
  HTTP_CODE=${RESPONSE: -3}
  
  # Save API response for debugging
  echo "API Response (HTTP $HTTP_CODE):" >> $LOG_FILE
  cat /tmp/github_response.json >> $LOG_FILE

  # Check for HTTP errors
  if [ $HTTP_CODE -ne 200 ]; then
    ERROR_MSG=$(grep -o '"message": *"[^"]*"' /tmp/github_response.json | sed 's/"message": *"\(.*\)"/\1/')
    handle_api_error $HTTP_CODE "$ERROR_MSG"
    
    if [ $HTTP_CODE -eq 403 ]; then
      # Check when rate limit resets
      RESET_TIME=$(curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit | grep -o '"reset": *[0-9]*' | grep -o '[0-9]*')
      if [ ! -z "$RESET_TIME" ]; then
        RESET_TIME_HUMAN=$(date -d @$RESET_TIME)
        echo "Rate limit resets at: $RESET_TIME_HUMAN" | tee -a $LOG_FILE
      fi
    fi
    
    sleep $((ATTEMPT * 10))
    ATTEMPT=$((ATTEMPT+1))
    continue
  fi

  # Extract version with proper error handling
  LATEST_VERSION=$(grep -o '"tag_name": *"[^"]*"' /tmp/github_response.json | sed 's/"tag_name": *"\(.*\)"/\1/')
  
  if [ -z "$LATEST_VERSION" ]; then
    echo "Could not parse version. Attempt $ATTEMPT of $MAX_ATTEMPTS." | tee -a $LOG_FILE
    echo "Checking if API returned an error message..." | tee -a $LOG_FILE
    ERROR_MSG=$(grep -o '"message": *"[^"]*"' /tmp/github_response.json | sed 's/"message": *"\(.*\)"/\1/')
    if [ ! -z "$ERROR_MSG" ]; then
      echo "GitHub API error: $ERROR_MSG" | tee -a $LOG_FILE
    fi
    sleep 5
    ATTEMPT=$((ATTEMPT+1))
  fi
done

# If all attempts failed
if [ -z "$LATEST_VERSION" ]; then
  echo "Error: Could not fetch latest version from GitHub API after $MAX_ATTEMPTS attempts" | tee -a $LOG_FILE
  echo "Check $LOG_FILE for details"
  exit 2
fi

echo "Latest version from GitHub: $LATEST_VERSION" | tee -a $LOG_FILE

# Compare versions (semantic version comparison)
CURRENT_WITHOUT_PREFIX=${CURRENT_VERSION#Meow-v}
LATEST_WITHOUT_PREFIX=${LATEST_VERSION#Meow-v}

function version_gt() {
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

echo "Comparing versions: current=$CURRENT_WITHOUT_PREFIX, latest=$LATEST_WITHOUT_PREFIX" | tee -a $LOG_FILE

if version_gt "$LATEST_WITHOUT_PREFIX" "$CURRENT_WITHOUT_PREFIX"; then
  echo "New version available: $LATEST_VERSION (current: $CURRENT_VERSION)" | tee -a $LOG_FILE
  echo "$LATEST_VERSION" > meowcoin_version.txt
  
  # Configure git with retry mechanism
  echo "Configuring git" | tee -a $LOG_FILE
  git config --global user.name "GitHub Actions Bot"
  git config --global user.email "actions@github.com"
  
  # Add commit message with details
  COMMIT_MSG="Update Meowcoin to version $LATEST_VERSION [skip ci]

This is an automated update from $CURRENT_VERSION to $LATEST_VERSION.
Changes: https://github.com/Meowcoin-Foundation/Meowcoin/compare/$CURRENT_VERSION...$LATEST_VERSION"
  
  # Commit and push changes
  echo "Committing changes" | tee -a $LOG_FILE
  git add meowcoin_version.txt
  git commit -m "$COMMIT_MSG"
  
  # Retry git push up to 3 times if it fails
  MAX_PUSH_ATTEMPTS=3
  PUSH_ATTEMPT=1
  PUSH_SUCCESS=false
  
  while [ $PUSH_ATTEMPT -le $MAX_PUSH_ATTEMPTS ] && [ "$PUSH_SUCCESS" = "false" ]; do
    echo "Pushing changes (attempt $PUSH_ATTEMPT/$MAX_PUSH_ATTEMPTS)" | tee -a $LOG_FILE
    if git push; then
      PUSH_SUCCESS=true
      echo "Push successful" | tee -a $LOG_FILE
    else
      echo "Git push failed. Attempt $PUSH_ATTEMPT of $MAX_PUSH_ATTEMPTS." | tee -a $LOG_FILE
      
      # Check for specific git errors
      git fetch
      DIVERGED=$(git status | grep -c "diverged" || true)
      if [ $DIVERGED -gt 0 ]; then
        echo "Branches have diverged, attempting to resolve" | tee -a $LOG_FILE
        git pull --rebase
      fi
      
      sleep 5
      PUSH_ATTEMPT=$((PUSH_ATTEMPT+1))
    fi
  done
  
  if [ "$PUSH_SUCCESS" = "false" ]; then
    echo "Error: Failed to push changes after $MAX_PUSH_ATTEMPTS attempts - check network connection and repository permissions" | tee -a $LOG_FILE
    exit 2
  fi
  
  echo "Version updated to $LATEST_VERSION" | tee -a $LOG_FILE
  echo "::set-output name=new_version::$LATEST_VERSION"
  echo "::set-output name=version_changed::true"
  exit 0
else
  echo "Already using the latest version: $CURRENT_VERSION" | tee -a $LOG_FILE
  echo "::set-output name=version_changed::false"
  exit 0
fi