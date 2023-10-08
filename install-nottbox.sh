#!/bin/bash

# Install git without prompting
sudo apt-get -y install git

# Prompt the user to confirm if they want to enable the service
read -p "Do you want to enable the Nottbox service to start on boot? (Y/n): " enable_service

if [ "$enable_service" != "n" ]; then
    # Clone the repository
    git clone https://github.com/sam-morin/nottbox.git

    # Navigate to the cloned directory
    cd nottbox

    # Make the script executable
    chmod +x nottbox.sh

    # Copy the systemd service file to the appropriate location
    sudo cp nottbox.service /etc/systemd/system/

    # Prompt the user to edit the YAML file using vi
    read -p "Do you want to edit the Nottbox default config file? (Y/n): " edit_yaml

    if [ "$edit_yaml" != "n" ]; then
        sudo vi /root/nottbox/nottbox.yml
    else
        echo "You chose not to edit the YAML file."
    fi

    # Reload systemd daemon to pick up the new service
    sudo systemctl daemon-reload

    # Enable the service to start on boot
    sudo systemctl enable nottbox

    # Start the service
    sudo systemctl start nottbox

    # Check the status of the service
    sudo systemctl status nottbox
else
    echo "Service 'nottbox' will not be enabled to start on boot."
fi
