#!/bin/bash

# Parse command-line options
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -f|--remove-log)
            remove_log=true
            shift
            ;;
        *)
            echo "Unknown option: $key"
            exit 1
            ;;
    esac
done

# Stop the Nottbox service if it's running
echo ""
echo "Stopping the Nottbox service..."
systemctl stop nottbox

# Disable the Nottbox service from starting on boot if it's enabled
echo ""
echo "Disabling the Nottbox service..."
systemctl disable nottbox

# Remove the Nottbox service unit file
echo ""
echo "Deleting the Nottbox service..."
rm /etc/systemd/system/nottbox.service

# Reload systemd daemon after removing the service file
echo ""
echo "Reloading systemd daemomn..."
systemctl daemon-reload

# Move log file to /root/nottbox.log
if [ "$remove_log" != true ]; then
    mv /root/nottbox/nottbox.log /root/nottbox.log
fi

# Remove the Nottbox directory
echo ""
echo "Removing the Nottbox directory..."
rm -rf /root/nottbox

# Uninstall the git package
echo ""
echo "Uninstalling git..."
apt-get remove --purge git -y

# Clean up unused packages and dependencies (optional)
echo ""
echo "Cleaning up packages..."
apt-get autoremove -y

echo ""
echo "Nottbox has been uninstalled, and the git package has been removed."

# Schedule self-destruct using 'at' command
# echo "rm -- \"\$0\"" | at now + 15 seconds

# echo ""
# echo "This uninstall script will self-destruct in 10 seconds."
echo ""
echo "Thank you for using Nottbox! - https://github.com/sam-morin/nottbox"
echo ""

# Exit the script gracefully
exit 0
