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

# Hard-code the path to the update script (repo path)
UPDATE_SCRIPT_PATH="$REPO_PATH/update_check.sh"

# Hard-code the path to the service file template
SERVICE_TEMPLATE="$REPO_PATH/template/systemd_service_template.service"

# Generic function to prompt for replacing, skipping, or quitting a step
prompt_replace_or_skip() {
    local step="$1"
    local choice
    while true; do
        echo "$step already exists. Do you want to replace it? (y: replace, n: skip, q: quit)"
        read -p "Enter your choice: " choice
        case "$choice" in
            y|Y)
                echo "Replacing $step..."
                return 0  # Indicate that we should perform the replacement
                ;;
            n|N)
                echo "Skipping $step..."
                return 1  # Indicate that we should skip the action
                ;;
            q|Q)
                echo "Exiting the setup."
                exit 0  # Exit the script
                ;;
            *)
                echo "Invalid choice. Please enter y, n, or q."
        esac
    done
}

# Generic function to perform a task (only if needed)
perform_action() {
    local step="$1"
    local condition="$2"
    local action="$3"
    
    if $condition; then
        prompt_replace_or_skip "$step"
        if [ $? -eq 0 ]; then
            eval "$action"
        fi
    else
        echo "$step does not exist. Proceeding with action..."
        eval "$action"
    fi
}

# Step 1: Create the User for the Game Server
create_user() {
    sudo useradd -r -m -s /bin/bash $SERVICE_USER
    sudo chown -R $SERVICE_USER:$SERVICE_GROUP $GAME_DIR
}

# Step 2: Install Dependencies for the Game Server
install_dependencies() {
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y wget lib32gcc-s1 ufw
}

# Step 3: Download and Install SteamCMD
install_steamcmd() {
    cd /root
    wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    tar -xvf steamcmd_linux.tar.gz
}

# Step 4: Install the Game using SteamCMD
install_game() {
    $STEAMCMD_DIR/steamcmd.sh +login anonymous +force_install_dir $GAME_DIR +app_update $STEAM_APP_ID validate +quit
}

# Step 5: Update the Version in the Config File
update_version() {
    CURRENT_VERSION=$($STEAMCMD_DIR/steamcmd.sh +login anonymous +force_install_dir $GAME_DIR +app_info_update 1 +app_info_print $STEAM_APP_ID +quit | grep -oP '(?<=buildid":)[0-9]+')

    # Update the config file with the new version
    if [ ! -z "$CURRENT_VERSION" ]; then
        echo "Updating version to $CURRENT_VERSION in the config file..."
        sed -i "s/^STEAM_APP_VERSION=\".*\"/STEAM_APP_VERSION=\"$CURRENT_VERSION\"/" $CONFIG_FILE
    else
        echo "Failed to get the current version. Exiting."
        exit 1
    fi
}

# Step 6: Open Ports for the Game
open_ports() {
    sudo ufw allow $PORTS_TCP && sudo ufw allow $PORTS_UDP
}

# Step 7: Configure the Game to Run as a Service
create_service() {
    if [ ! -f "/etc/systemd/system/$SERVICE_NAME" ]; then
        echo "Creating systemd service for $GAME_NAME..."

        # Create a temporary service file with the replaced values
        sed "s/{{GAME_NAME}}/$GAME_NAME/g;
             s/{{SERVICE_USER}}/$SERVICE_USER/g;
             s/{{GAME_DIR}}/$GAME_DIR/g;
             s/{{EXEC_START}}/$EXEC_START/g" \
             $SERVICE_TEMPLATE > /etc/systemd/system/$SERVICE_NAME
    else
        echo "Systemd service file already exists."
    fi
}

# Step 8: Enable and Start the Service
enable_and_start_service() {
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
}

# Step 9: Set Up Cron Job for Regular Updates
setup_cron() {
    (crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $UPDATE_SCRIPT_PATH") | crontab -
}

# Main Script Logic to Execute Each Step with Conditional Check

# Step 1: Create User for the Game Server
perform_action "User $SERVICE_USER" "id \"$SERVICE_USER\" &>/dev/null" "create_user"

# Step 2: Install Dependencies for the Game Server
perform_action "Dependencies for the game" "dpkg -l | grep -q wget" "install_dependencies"

# Step 3: Download and Install SteamCMD
perform_action "SteamCMD directory $STEAMCMD_DIR" "[ -d \"$STEAMCMD_DIR\" ]" "install_steamcmd"

# Step 4: Install the Game using SteamCMD
perform_action "Game directory $GAME_DIR" "[ -d \"$GAME_DIR\" ]" "install_game"

# Step 5: Update Version in Config File
update_version

# Step 6: Open Ports for the Game
perform_action "Firewall ports" "sudo ufw status | grep -q \"$PORTS_TCP\"" "open_ports"

# Step 7: Configure the Game to Run as a Service
perform_action "Systemd service for $SERVICE_NAME" "[ -f \"/etc/systemd/system/$SERVICE_NAME\" ]" "create_service"

# Step 8: Enable and Start the Service
enable_and_start_service

# Step 9: Set Up Cron Job for Regular Updates
setup_cron

# Check the status of the service
sudo systemctl status $SERVICE_NAME
