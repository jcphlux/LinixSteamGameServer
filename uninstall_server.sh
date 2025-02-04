#!/bin/bash

# Get the current directory (repo path)
REPO_PATH=$(pwd)

# Check if game name is passed as an argument
if [ -z "$1" ]; then
    echo "Please provide the game name (e.g., 7d2d)."
    exit 1
fi

# Define the config file path dynamically based on the game name
GAME_NAME="$1"
CONFIG_FILE="$REPO_PATH/config/server_config_${GAME_NAME}.cfg"

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE not found!"
    exit 1
fi

# Source the config file (this will load the variables into the script)
source $CONFIG_FILE

# Confirmation step
echo "Are you sure you want to uninstall the server? Type 'uninstall' to confirm:"
read CONFIRMATION
if [ "$CONFIRMATION" != "uninstall" ]; then
    echo "Uninstallation aborted."
    exit 1
fi

# Step 1: Stop and Disable the Service
echo "Stopping and disabling the service..."
sudo systemctl stop $SERVICE_NAME
sudo systemctl disable $SERVICE_NAME

# Step 2: Remove the Systemd Service File
echo "Removing the systemd service file..."
sudo rm -f /etc/systemd/system/$SERVICE_NAME
sudo systemctl daemon-reload

# Step 3: Remove the Game Directory
echo "Removing the game directory..."
sudo rm -rf $GAME_DIR

# Step 4: Remove the User and Group
echo "Removing the user and group..."
sudo userdel -r $SERVICE_USER
sudo groupdel $SERVICE_GROUP

# Step 5: Remove the Config File from User's Home Directory
echo "Removing the config file from the user's home directory..."
sudo rm -f /home/$SERVICE_USER/server_config_${GAME_NAME}.cfg

# Step 6: Remove Cron Job for Regular Updates
echo "Removing the cron job for regular updates..."
(crontab -l | grep -v "$UPDATE_SCRIPT_PATH") | crontab -

# Step 7: Remove Firewall Rules
echo "Removing firewall rules..."
sudo ufw delete allow $PORTS_TCP
sudo ufw delete allow $PORTS_UDP

echo "Uninstallation completed."
