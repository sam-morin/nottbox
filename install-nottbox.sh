#!/bin/bash

USER_KEY=""
API_TOKEN=""
ENV_FILE=".env.pushover"

# Parse command-line options
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -e|--enable-service)
            enable_service=true
            shift
            ;;
        -u|--user-key)
            USER_KEY="$2"
            shift 2
            ;;
        -t|--api-token)
            API_TOKEN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $key"
            exit 1
            ;;
    esac
done

# Install git without prompting
echo ""
echo "Installing git..."
sudo apt-get -y install git > /dev/null 2>&1;

# Clone the repository
echo ""
echo "Clone the repo and CD into the nottbox directory..."
git clone https://github.com/sam-morin/nottbox.git
# Navigate to the cloned directory
cd nottbox

# Uninstall the git package
echo ""
echo "Uninstalling git..."
apt-get remove --purge git -y > /dev/null 2>&1;

# Clean up unused packages and dependencies (optional)
echo ""
echo "Cleaning up packages..."
apt-get autoremove -y > /dev/null 2>&1;

# Function to create the .env.pushover file
create_env_file() {
    echo "USER_KEY=$USER_KEY" > "$ENV_FILE"
    echo "API_TOKEN=$API_TOKEN" >> "$ENV_FILE"
    echo "Environment variables saved to $ENV_FILE"
}

# Create the .env.pushover file if USER_KEY and API_TOKEN are provided
if [ -n "$USER_KEY" ] && [ -n "$API_TOKEN" ]; then
    echo "Pushover keys passed! Creating .env.pushover file..."
    create_env_file
fi

# Make the script executable
echo ""
echo "Making nottbox script executable..."
chmod +x nottbox.sh

# Copy the systemd service file to the appropriate location
echo ""
echo "Setting up nottbox.service..."
sudo cp nottbox.service /etc/systemd/system/

# Reload systemd daemon to pick up the new service
echo ""
echo "Reloading the systemd daemon..."
sudo systemctl daemon-reload

# Enable the service if specified
if [ "$enable_service" == true ]; then
    # Enable the service to start on boot
    echo ""
    echo "Enabling nottbox.service (to restart on boot)"
    sudo systemctl enable nottbox
else
    echo ""
    echo "The Nottbox service will NOT be enabled on boot! This is probably not a good idea as Nottbox will only work once until it is started again after reboot!"
fi

# Start the service
echo ""
echo "Starting the Nottbox service..."
sudo systemctl start nottbox

# Check the status of the service
echo ""
echo "Service Status:"
sudo systemctl status nottbox