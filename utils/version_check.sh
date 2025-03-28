#!/bin/bash
set -e

# GitHub API URL for Meowcoin releases
GITHUB_API="https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest"
# Log file for debugging with timestamp
LOG_FILE="version_check_$(date +%Y%m%d_%H%M%S).log"

echo "Starting version check at $(date -Iseconds)" > $LOG_FILE

# Function to handle API errors with detailed diagnostics
function handle_api_error() {
  local ERROR_CODE=$1
  local ERROR_MSG=$2
  local RESPONSE_FILE=$3
  
  echo "GitHub API error (${ERROR_CODE}): ${ERROR_MSG}" | tee -a $LOG_FILE
  
  # Save full response for debugging
  if [ -f "$RESPONSE_FILE" ]; then
    echo "Full API response:" >> $LOG_FILE
    cat "$RESPONSE_FILE" >> $LOG_FILE
  fi
  
  case $ERROR_CODE in
    403)
      echo "Rate limit exceeded or access denied" | tee -a $LOG_FILE
      # Check rate limit information
      RATE_LIMIT_INFO=$(curl -s https://api.github.com/rate_limit)
      echo "Rate limit information:" >> $LOG_FILE
      echo "$RATE_LIMIT_INFO" >> $LOG_FILE
      
      # Extract rate limit reset time
      RESET_TIME=$(echo "$RATE_LIMIT_INFO" | grep -o '"reset": *[0-9]*' | grep -o '[0-9]*' | head -1)
      if [ ! -z "$RESET_TIME" ]; then
        RESET_TIME_HUMAN=$(date -d @$RESET_TIME)
        echo "Rate limit resets at: $RESET_TIME_HUMAN" | tee -a $LOG_FILE
      fi
      ;;
    404)
      echo "Repository or resource not found. Verify the repository URL is correct." | tee -a $LOG_FILE
      ;;
    401)
      echo "Authentication failed. Verify your GitHub token has correct permissions." | tee -a $LOG_FILE
      ;;
    422)
      echo "Validation failed. The request may be malformed." | tee -a $LOG_FILE
      ;;
    500|502|503|504)
      echo "GitHub server error. This is likely a temporary issue." | tee -a $LOG_FILE
      ;;
    *)
      echo "Unexpected error occurred. See log for details." | tee -a $LOG_FILE
      ;;
  esac
}

# Validate GitHub token if provided
GH_HEADER=""
if [ ! -z "$GITHUB_TOKEN" ]; then
  if [[ ! $GITHUB_TOKEN =~ ^gh[ps]_[a-zA-Z0-9_]{36,251}$ ]]; then
    echo "Warning: GitHub token format appears invalid. Token should start with 'ghp_' or 'ghs_'" | tee -a $LOG_FILE
  fi
  GH_HEADER="Authorization: token $GITHUB_TOKEN"
  echo "Using provided GitHub token for authentication" | tee -a $LOG_FILE
else
  echo "No GitHub token provided. Requests may be rate limited." | tee -a $LOG_FILE
fi

# Get the current version from our file
if [ ! -f "meowcoin_version.txt" ]; then
  echo "Error: meowcoin_version.txt file not found" | tee -a $LOG_FILE
  exit 1
fi

CURRENT_VERSION=$(cat meowcoin_version.txt)
echo "Current version: $CURRENT_VERSION" | tee -a $LOG_FILE

# Validate version format
if [[ ! $CURRENT_VERSION =~ ^Meow-v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "Warning: Current version format doesn't match expected pattern (Meow-v1.2.3)" | tee -a $LOG_FILE
fi

# Get the latest version from GitHub with rate limit handling
MAX_ATTEMPTS=3
ATTEMPT=1
LATEST_VERSION=""
RESPONSE_FILE="/tmp/github_response_$(date +%s).json"

while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ -z "$LATEST_VERSION" ]; do
  echo "Fetching from GitHub API (attempt $ATTEMPT/$MAX_ATTEMPTS)" | tee -a $LOG_FILE
  
  # Use timeout to prevent hanging requests
  if [ -z "$GH_HEADER" ]; then
    RESPONSE=$(curl -s -w "%{http_code}" -H "Accept: application/vnd.github.v3+json" \
               --connect-timeout 10 --max-time 30 \
               $GITHUB_API -o $RESPONSE_FILE)
  else
    RESPONSE=$(curl -s -w "%{http_code}" -H "$GH_HEADER" -H "Accept: application/vnd.github.v3+json" \
               --connect-timeout 10 --max-time 30 \
               $GITHUB_API -o $RESPONSE_FILE)
  fi
  
  HTTP_CODE=${RESPONSE: -3}
  
  # Save API response for debugging
  echo "API Response (HTTP $HTTP_CODE):" >> $LOG_FILE
  if [ -f "$RESPONSE_FILE" ]; then
    cat "$RESPONSE_FILE" >> $LOG_FILE
  else
    echo "No response file created" >> $LOG_FILE
  fi

  # Check for HTTP errors
  if [ $HTTP_CODE -ne 200 ]; then
    ERROR_MSG=$(grep -o '"message": *"[^"]*"' "$RESPONSE_FILE" 2>/dev/null | head -1 | sed 's/"message": *"\(.*\)"/\1/')
    if [ -z "$ERROR_MSG" ]; then
      ERROR_MSG="Unknown error"
    fi
    
    handle_api_error $HTTP_CODE "$ERROR_MSG" "$RESPONSE_FILE"
    
    if [ $HTTP_CODE -eq 403 ]; then
      # For rate limiting, use exponential backoff
      SLEEP_TIME=$((ATTEMPT * ATTEMPT * 5))
      echo "Retrying in $SLEEP_TIME seconds..." | tee -a $LOG_FILE
      sleep $SLEEP_TIME
    else
      # For other errors, use linear backoff
      SLEEP_TIME=$((ATTEMPT * 5))
      echo "Retrying in $SLEEP_TIME seconds..." | tee -a $LOG_FILE
      sleep $SLEEP_TIME
    fi
    
    ATTEMPT=$((ATTEMPT+1))
    continue
  fi

  # Extract version with proper error handling
  LATEST_VERSION=$(grep -o '"tag_name": *"[^"]*"' "$RESPONSE_FILE" | head -1 | sed 's/"tag_name": *"\(.*\)"/\1/')
  
  if [ -z "$LATEST_VERSION" ]; then
    echo "Could not parse version. Attempt $ATTEMPT of $MAX_ATTEMPTS." | tee -a $LOG_FILE
    echo "Checking if API returned an error message..." | tee -a $LOG_FILE
    ERROR_MSG=$(grep -o '"message": *"[^"]*"' "$RESPONSE_FILE" 2>/dev/null | head -1 | sed 's/"message": *"\(.*\)"/\1/')
    if [ ! -z "$ERROR_MSG" ]; then
      echo "GitHub API error: $ERROR_MSG" | tee -a $LOG_FILE
    fi
    
    # Validate JSON response
    if ! jq empty "$RESPONSE_FILE" 2>/dev/null; then
      echo "Invalid JSON response received" | tee -a $LOG_FILE
      cat "$RESPONSE_FILE" >> $LOG_FILE
    fi
    
    sleep 5
    ATTEMPT=$((ATTEMPT+1))
  fi
done

# Cleanup response file
rm -f "$RESPONSE_FILE"

# If all attempts failed
if [ -z "$LATEST_VERSION" ]; then
  echo "Error: Could not fetch latest version from GitHub API after $MAX_ATTEMPTS attempts" | tee -a $LOG_FILE
  echo "Check $LOG_FILE for details"
  exit 2
fi

# Validate latest version format
if [[ ! $LATEST_VERSION =~ ^Meow-v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "Warning: Latest version format doesn't match expected pattern (Meow-v1.2.3)" | tee -a $LOG_FILE
fi

echo "Latest version from GitHub: $LATEST_VERSION" | tee -a $LOG_FILE

# Compare versions (semantic version comparison)
CURRENT_WITHOUT_PREFIX=${CURRENT_VERSION#Meow-v}
LATEST_WITHOUT_PREFIX=${LATEST_VERSION#Meow-v}

# Improved version comparison function that handles pre-release tags
function version_gt() {
  local IFS=.
  local i ver1=($1) ver2=($2)
  
  # Fill empty fields with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
    ver2[i]=0
  done
  
  # Compare version numbers
  for ((i=0; i<${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      ver2[i]=0
    fi
    
    # Handle non-numeric parts (like "-beta1")
    if [[ ${ver1[i]} =~ ^[0-9]+$ ]] && [[ ${ver2[i]} =~ ^[0-9]+$ ]]; then
      # Both are numeric, do numeric comparison
      if ((10#${ver1[i]} > 10#${ver2[i]})); then
        return 0
      elif ((10#${ver1[i]} < 10#${ver2[i]})); then
        return 1
      fi
    else
      # Handle alpha/beta/rc tags - stable versions are greater than pre-release
      if [[ ${ver1[i]} =~ ^[0-9]+$ ]] && [[ ! ${ver2[i]} =~ ^[0-9]+$ ]]; then
        # ver1 is numeric but ver2 is pre-release
        return 0
      elif [[ ! ${ver1[i]} =~ ^[0-9]+$ ]] && [[ ${ver2[i]} =~ ^[0-9]+$ ]]; then
        # ver1 is pre-release but ver2 is numeric
        return 1
      else
        # Both are strings, do string comparison
        if [[ "${ver1[i]}" > "${ver2[i]}" ]]; then
          return 0
        elif [[ "${ver1[i]}" < "${ver2[i]}" ]]; then
          return 1
        fi
      fi
    fi
  done
  return 1
}

echo "Comparing versions: current=$CURRENT_WITHOUT_PREFIX, latest=$LATEST_WITHOUT_PREFIX" | tee -a $LOG_FILE

if version_gt "$LATEST_WITHOUT_PREFIX" "$CURRENT_WITHOUT_PREFIX"; then
  echo "New version available: $LATEST_VERSION (current: $CURRENT_VERSION)" | tee -a $LOG_FILE
  
  # Backup current version file
  cp meowcoin_version.txt meowcoin_version.txt.bak
  
  # Update version file
  echo "$LATEST_VERSION" > meowcoin_version.txt
  
  # Verify file was written correctly
  if [ "$(cat meowcoin_version.txt)" != "$LATEST_VERSION" ]; then
    echo "Error: Failed to write new version to file" | tee -a $LOG_FILE
    if [ -f meowcoin_version.txt.bak ]; then
      mv meowcoin_version.txt.bak meowcoin_version.txt
    fi
    exit 3
  fi
  
  # Configure git with retry mechanism
  echo "Configuring git" | tee -a $LOG_FILE
  git config --global user.name "GitHub Actions Bot"
  git config --global user.email "actions@github.com"
  
  # Validate URLs before using them in commit message
  REPO_URL="https://github.com/Meowcoin-Foundation/Meowcoin"
  COMPARE_URL="$REPO_URL/compare/${CURRENT_VERSION}...${LATEST_VERSION}"
  
  # Sanitize URLs
  COMPARE_URL=$(echo "$COMPARE_URL" | sed 's/[^a-zA-Z0-9:/.\_-]//g')
  
  # Add commit message with details
  COMMIT_MSG="Update Meowcoin to version $LATEST_VERSION [skip ci]

This is an automated update from $CURRENT_VERSION to $LATEST_VERSION.
Changes: $COMPARE_URL"
  
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
      PUSH_ERROR=$?
      echo "Git push failed with error code $PUSH_ERROR. Attempt $PUSH_ATTEMPT of $MAX_PUSH_ATTEMPTS." | tee -a $LOG_FILE
      
      # Check for specific git errors
      git fetch
      DIVERGED=$(git status | grep -c "diverged" || true)
      if [ $DIVERGED -gt 0 ]; then
        echo "Branches have diverged, attempting to resolve" | tee -a $LOG_FILE
        git pull --rebase
      fi
      
      # Use exponential backoff
      SLEEP_TIME=$((PUSH_ATTEMPT * PUSH_ATTEMPT * 5))
      echo "Retrying in $SLEEP_TIME seconds..." | tee -a $LOG_FILE
      sleep $SLEEP_TIME
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