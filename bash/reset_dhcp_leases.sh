#!/usr/local/bin/bash

# Get the process ID of 'unbound'
pid=$(ps | grep 'unbound' | awk '{print $1}')

# Check if the PID was found
if [ -z "$pid" ]; then
  echo "unbound process not found."
  exit 1
fi

# Send HUP signal to the process
pkill -HUP $pid

# Check if the file exists
if [ ! -f "/var/unbound/dhcpleases.conf" ]; then
  # If the file does not exist, restart the unbound service
  echo "File not found, restarting unbound service."
  service unbound onerestart

else
  # If the file exists, remove it
  rm /var/unbound/dhcpleases.conf
fi

echo "Operation completed"