#!/bin/bash

# Parse command-line options
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -e|--enable-service)
            enable_service=true
            shift
            ;;
        -y|--edit-yaml)
            edit_yaml=true
            shift
            ;;
        *)
            echo "Unknown option: $key"
            exit 1
            ;;
    esac
done

# Install git without prompting
sudo apt-get -y install git

# Clone the repository
git clone https://github.com/sam-morin/nottbox.git

# Navigate to the cloned directory
cd nottbox

# Make the script executable
chmod +x nottbox.sh

# Copy the systemd service file to the appropriate location
sudo cp nottbox.service /etc/systemd/system/

# Reload systemd daemon to pick up the new service
sudo systemctl daemon-reload

# Edit the YAML file if specified
if [ "$edit_yaml" == true ]; then
    vi nottbox.yml
fi

# Enable the service if specified
if [ "$enable_service" == true ]; then

    # Enable the service to start on boot
    sudo systemctl enable nottbox
else
    echo "The Nottbox service will NOT be enabled on boot! This is probably not a good idea as Nottbox will only work once until it is started again after reboot!"
fi

# Start the service
sudo systemctl start nottbox

# Check the status of the service
sudo systemctl status nottbox