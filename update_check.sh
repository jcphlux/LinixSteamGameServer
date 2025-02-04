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

# Check if the config file exists (exit if not found)
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE not found!"
    exit 1
fi

# Source the config file (this will load the variables into the script)
source $CONFIG_FILE

# Step 1: Update All Packages on the Server
echo "Updating all packages on the server..."
sudo apt update && sudo apt upgrade -y

# Step 2: Get the Current Version
CURRENT_VERSION=$STEAM_APP_VERSION
echo "Current version from config: $CURRENT_VERSION"

# Step 3: Check the Latest Version Available on Steam
LATEST_VERSION=$($STEAMCMD_DIR/steamcmd.sh +login anonymous +force_install_dir $GAME_DIR +app_info_update 1 +app_info_print $STEAM_APP_ID +quit | grep -oP '(?<=buildid":)[0-9]+')

# If no version info found, exit
if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to get the latest version. Exiting."
    exit 1
fi

echo "Latest version on Steam: $LATEST_VERSION"

# Step 4: Compare Versions and Update if Necessary
if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
    echo "New version found. Updating $GAME_NAME..."

    # Stop the server before updating
    sudo systemctl stop $SERVICE_NAME

    # Run the update using SteamCMD
    $STEAMCMD_DIR/steamcmd.sh +login anonymous +force_install_dir $GAME_DIR +app_update $STEAM_APP_ID validate +quit

    # After update, update the version in the config file
    echo "Updating version to $LATEST_VERSION in the config file..."
    sed -i "s/^STEAM_APP_VERSION=\".*\"/STEAM_APP_VERSION=\"$LATEST_VERSION\"/" $CONFIG_FILE

    # Restart the server after the update
    sudo systemctl start $SERVICE_NAME

    echo "Update completed and server restarted."
else
    echo "$GAME_NAME is up to date. No update required."
fi
