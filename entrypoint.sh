#!/bin/bash

# Check if custom config file exists and use it
if [ -f /config/meowcoin.conf ]; then
  echo "Using custom config from mounted volume"
  cp /config/meowcoin.conf /home/meowcoin/.meowcoin/meowcoin.conf
  chown meowcoin:meowcoin /home/meowcoin/.meowcoin/meowcoin.conf
fi

# Handle CLI commands
if [ "$1" = "cli" ]; then
  shift
  exec su -c "meowcoin-cli -conf=/home/meowcoin/.meowcoin/meowcoin.conf \"$@\"" meowcoin
elif [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
  exec /bin/bash
elif [ "$1" = "getpassword" ]; then
  if [ -f /home/meowcoin/.meowcoin/rpcpassword ]; then
    cat /home/meowcoin/.meowcoin/rpcpassword
  else
    echo "Password file not found. Using custom configuration."
  fi
elif [ "$1" = "status" ]; then
  /usr/local/bin/update-status.sh
  cat /var/www/html/status.txt
  exit 0
else
  # Create initial status file
  echo "Meowcoin Node Status
-------------------
Status: Starting..." > /var/www/html/status.txt
  
  # Start web server
  cd /var/www/html
  python3 -m http.server 8080 &
  WEB_SERVER_PID=$!
  
  # Display information
  if [ -f /home/meowcoin/.meowcoin/rpcpassword ]; then
    PASSWORD=$(cat /home/meowcoin/.meowcoin/rpcpassword)
    echo "--------------------------------------------------------"
    echo "RPC Credentials:"
    echo "Username: meowcoin"
    echo "Password: ${PASSWORD}"
    echo "--------------------------------------------------------"
    echo "Use these credentials to connect to the RPC interface"
    echo "You can also retrieve this password with:"
    echo "docker exec meowcoin-node entrypoint.sh getpassword"
    echo "--------------------------------------------------------"
    echo "Web Status Dashboard: http://localhost:8080"
    echo "--------------------------------------------------------"
  fi
  
  # Start background status updater
  (while true; do
    /usr/local/bin/update-status.sh
    sleep 10
  done) &
  STATUS_PID=$!
  
  # Run the daemon
  echo "Starting Meowcoin daemon..."
  su -c "meowcoind -conf=/home/meowcoin/.meowcoin/meowcoin.conf" meowcoin
  
  # If meowcoind exits, kill the background processes
  kill $WEB_SERVER_PID 2>/dev/null
  kill $STATUS_PID 2>/dev/null
fi