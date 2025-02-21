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
        y | Y)
            echo "Replacing $step..."
            return 0 # Indicate that we should perform the replacement
            ;;
        n | N)
            echo "Skipping $step..."
            return 1 # Indicate that we should skip the action
            ;;
        q | Q)
            echo "Exiting the setup."
            exit 0 # Exit the script
            ;;
        *)
            echo "Invalid choice. Please enter y, n, or q."
            ;;
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
    echo "Creating user $SERVICE_USER..."
    sudo useradd -r -m -s /bin/bash $SERVICE_USER
    sudo chown -R $SERVICE_USER:$SERVICE_GROUP $GAME_DIR
}

# Step 2: Copy the config file to the user's home directory
copy_config_file() {
    echo "Copying the config file to the user's home directory..."
    sudo cp $CONFIG_FILE $USER_DIR/
    sudo chown $SERVICE_USER:$SERVICE_GROUP $USER_DIR/server_config_${GAME_NAME}.cfg
}

# Step 3: Install Dependencies for the Game Server
install_dependencies() {
    echo "Installing dependencies for the game server..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y wget lib32gcc-s1 ufw
}

# Step 4: Download and Install SteamCMD
install_steamcmd() {
    echo "Downloading and installing SteamCMD..."
    if [ ! -d "$STEAMCMD_DIR" ]; then
        sudo mkdir -p $STEAMCMD_DIR
        sudo chown -R $SERVICE_USER:$SERVICE_GROUP $STEAMCMD_DIR
    fi
    cd $STEAMCMD_DIR
    wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    tar -xvf steamcmd_linux.tar.gz
    sudo chown -R $SERVICE_USER:$SERVICE_GROUP $STEAMCMD_DIR
    chmod +x $STEAMCMD_DIR/steamcmd.sh
    # Remove the tar.gz file after extraction
    rm steamcmd_linux.tar.gz
}

# Step 5: Install the Game using SteamCMD
install_game() {
    echo "Installing the game using SteamCMD..."
    sudo -u $SERVICE_USER $STEAMCMD_DIR/steamcmd.sh +login anonymous +force_install_dir $GAME_DIR +app_update $STEAM_APP_ID validate +quit
}

# Step 6: Update the Version in the Config File
update_version() {
    echo "Running SteamCMD to check for current game version..."
    OUTPUT=$($STEAMCMD_DIR/steamcmd.sh +login anonymous +app_info_update 1 +app_info_print $STEAM_APP_ID +quit)

    # Extract build ID using the provided command
    echo "Attempting to extract build ID using the provided command..."
    CURRENT_VERSION=$(echo "$OUTPUT" | grep -EA 1000 "^\s+\"branches\"$" | grep -EA 5 "^\s+\"public\"$" | grep -m 1 -EB 10 "^\s+}$" | grep -E "^\s+\"buildid\"\s+" | tr '[:blank:]' ' ' | tr -s ' ' | cut -d' ' -f3)

    # Update the config file with the new version
    if [ ! -z "$CURRENT_VERSION" ]; then
        echo "Updating version to $CURRENT_VERSION in the config file..."
        sudo sed -i "s/^STEAM_APP_VERSION=\".*\"/STEAM_APP_VERSION=\"$CURRENT_VERSION\"/" $USER_DIR/server_config_${GAME_NAME}.cfg
    else
        echo "Failed to get the current version. Exiting."
        exit 1
    fi
}

# Step 7: Open Ports for the Game
open_ports() {
    echo "Opening firewall ports..."
    sudo ufw allow ${PORT_START}:${PORT_END}/tcp
    sudo ufw allow ${PORT_START}:${PORT_END}/udp
}

# Step 8: Configure the Game to Run as a Service
create_service() {
    if [ ! -f "/etc/systemd/system/$SERVICE_NAME" ]; then
        echo "Creating systemd service for $GAME_NAME..."

        # Create a temporary service file with the replaced values
        sed "s|{{GAME_NAME}}|$GAME_NAME|g;
             s|{{SERVICE_USER}}|$SERVICE_USER|g;
             s|{{GAME_DIR}}|$GAME_DIR|g;
             s|{{EXEC_START}}|$EXEC_START|g" \
            $SERVICE_TEMPLATE > /etc/systemd/system/$SERVICE_NAME
    else
        echo "Systemd service file already exists."
    fi
}

# Step 9: Enable and Start the Service
enable_and_start_service() {
    # Unmask the service if it's masked
    sudo systemctl unmask $SERVICE_NAME

    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
}

# Step 10: Set Up Cron Job for Regular Updates
setup_cron() {
    (
        crontab -l 2>/dev/null
        echo "$CRON_SCHEDULE $UPDATE_SCRIPT_PATH"
    ) | crontab -
}

# Step 11: Give User Permissions for All Files
give_user_permissions() {
    sudo chown -R $SERVICE_USER:$SERVICE_GROUP $REPO_PATH
}

# Step 12: Reload Systemd and Start the Service
reload_and_start_service() {
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
}

# Step 13: Configure SFTP Access for the Service User
configure_sftp_access() {
    echo "Configuring SFTP access for $SERVICE_USER..."
    sudo mkdir -p $USER_DIR/.ssh
    sudo chown $SERVICE_USER:$SERVICE_GROUP $USER_DIR/.ssh
    sudo chmod 700 $USER_DIR/.ssh

    # Generate SSH key pair
    sudo -u $SERVICE_USER ssh-keygen -t rsa -b 2048 -f $USER_DIR/.ssh/id_rsa -N ""
    sudo chown $SERVICE_USER:$SERVICE_GROUP $USER_DIR/.ssh/id_rsa
    sudo chown $SERVICE_USER:$SERVICE_GROUP $USER_DIR/.ssh/id_rsa.pub

    # Add the public key to authorized_keys
    sudo cat $USER_DIR/.ssh/id_rsa.pub | sudo tee $USER_DIR/.ssh/authorized_keys
    sudo chown $SERVICE_USER:$SERVICE_GROUP $USER_DIR/.ssh/authorized_keys
    sudo chmod 600 $USER_DIR/.ssh/authorized_keys

    sudo bash -c "cat >> /etc/ssh/sshd_config <<EOL

Match User $SERVICE_USER
    ChrootDirectory $GAME_DIR
    ForceCommand internal-sftp
    AllowTcpForwarding no
EOL"
}

# Display the public key at the end of the script
display_public_key() {
    echo "Public key for SFTP access:"
    echo 
    sudo cat $USER_DIR/.ssh/id_rsa.pub
    echo
    echo "Please copy the above public key."
    echo "Please add this public key to the authorized_keys file on the remote client you want to connect from."
}


# Main Script Logic to Execute Each Step with Conditional Check

# Step 1: Create User for the Game Server
perform_action "User $SERVICE_USER" "id \"$SERVICE_USER\" &>/dev/null" "create_user"

# Step 2: Copy the config file to the user's home directory
copy_config_file

# Step 3: Install Dependencies for the Game Server
perform_action "Dependencies for the game" "dpkg -l | grep -q wget" "install_dependencies"

# Step 4: Download and Install SteamCMD
perform_action "SteamCMD directory $STEAMCMD_DIR" "[ -d \"$STEAMCMD_DIR\" ]" "install_steamcmd"

# Step 5: Install the Game using SteamCMD
perform_action "Game directory $GAME_DIR" "[ -d \"$GAME_DIR\" ]" "install_game"

# Step 6: Update Version in Config File
update_version

# Step 7: Open Ports for the Game
perform_action "Firewall ports" "sudo ufw status | grep -q 'Status: active' && sudo ufw status | grep -q \"$PORTS_TCP\"" "open_ports"

# Step 8: Configure the Game to Run as a Service
perform_action "Systemd service for $SERVICE_NAME" "[ -f \"/etc/systemd/system/$SERVICE_NAME\" ]" "create_service"

# Step 9: Enable and Start the Service
enable_and_start_service

# Step 10: Set Up Cron Job for Regular Updates
setup_cron

# Step 11: Give User Permissions for All Files
give_user_permissions

# Step 12: Reload Systemd and Start the Service
reload_and_start_service

# Step 13: Configure SFTP Access for the Service User
configure_sftp_access

# Step 14: Display the Public Key for SFTP Access
display_public_key

echo "Displaying the status of the service. Press 'q' to exit the status screen."
# Prompt the user to press any key to continue
echo "Press any key to continue (or press Ctrl+C to exit)..."
read -n 1 -s
# Check the status of the service
sudo systemctl status $SERVICE_NAME
