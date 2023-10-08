#!/bin/bash

echo "Uninstalling Nottbox..."

# Stop the Nottbox service if it's running
systemctl stop nottbox

# Disable the Nottbox service from starting on boot if it's enabled
systemctl disable nottbox

# Remove the Nottbox service unit file
rm /etc/systemd/system/nottbox.service

# Reload systemd daemon after removing the service file
systemctl daemon-reload

# Remove the Nottbox directory
rm -rf /root/nottbox

# Uninstall the git package
apt-get remove --purge git -y

# Clean up unused packages and dependencies (optional)
apt-get autoremove -y

echo "Nottbox has been uninstalled."

# Self-destruct this script
rm -- "$0"

