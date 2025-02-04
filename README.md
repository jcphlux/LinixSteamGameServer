# LinuxSteamGameServer

<img src="./assets/LinuxSteamGameServer.png" alt="Project Logo" height="100">

This repository contains scripts and configuration files to set up, manage, and update Steam game servers on Linux.

## Features

- **setup_server.sh**: Automates the setup of Steam game servers on a Linux machine.
  - Creates a user for the game server.
  - Installs dependencies for SteamCMD and the game.
  - Installs SteamCMD.
  - Installs the game via SteamCMD.
  - Configures firewall ports.
  - Creates and configures a systemd service for the game.
  - Sets up a cron job for regular updates.

- **update_check.sh**: Checks for updates to the game server and applies them.
  - Updates the Linux system packages first.
  - Checks for the latest version of the game and updates it if necessary.
  - Restarts the game server after the update.

- **uninstall_server.sh**: Automates the uninstallation of the game server.
  - Stops and disables the systemd service.
  - Removes the systemd service file.
  - Deletes the game directory.
  - Removes the user and group created for the game server.
  - Deletes the config file from the user's home directory.
  - Removes the cron job for regular updates.
  - Deletes the firewall rules.

## Requirements

- Linux-based system (e.g., Ubuntu)
- Root or sudo access to install packages and configure services.
- SteamCMD installed (the script handles installation if not already installed).
- The game you wish to install and manage with SteamCMD (e.g., `7d2d` for 7 Days to Die).
- Git installed (if not, see the setup section below).

## Setup

1. **Install Git** (if not already installed):

   ```bash
   sudo apt update
   sudo apt install git -y
   ```

2. **Clone the repository**:

   ```bash
   git clone https://github.com/jcphlux/LinixSteamGameServer.git
   cd LinixSteamGameServer
   chmod +x *.sh
   ```

3. **Create the game-specific config file** in the `config/` directory. Use `server_config_template.cfg` to create new config files for different games.

4. **Run the setup script**:

   ```bash
   ./setup_server.sh 7d2d
   ```

   This will:
   - Load the configuration from `server_config_7d2d.cfg`.
   - Prompt you to replace or skip existing steps like user creation, SteamCMD installation, etc.

5. **To update the game server**:

   ```bash
   ./update_check.sh 7d2d
   ```

   This will:
   - Update all server packages using `apt`.
   - Check for any game updates and apply them.

6. **To uninstall the game server**:

   ```bash
   ./uninstall_server.sh 7d2d
   ```

   This will:
   - Stop and disable the systemd service.
   - Remove the systemd service file.
   - Delete the game directory.
   - Remove the user and group created for the game server.
   - Delete the config file from the user's home directory.
   - Remove the cron job for regular updates.
   - Delete the firewall rules.

## Configuration

Game-specific configuration is stored in the `config/` directory. The config files are named `server_config_<game_name>.cfg`, and you can modify them as needed for your specific game server setup. The template configuration file is `server_config_template.cfg`.

### Example `server_config_7d2d.cfg`:

```bash
# server_config_7d2d.cfg

# 7 Days to Die Steam App ID
STEAM_APP_ID="294420"

# Steam App Version (this will get updated by the script)
STEAM_APP_VERSION="0"

# The user and group to run the service under
SERVICE_USER="7d2d"
SERVICE_GROUP="7d2d"

# The game name (this will be used for directory paths and service name)
GAME_NAME="7d2d"

# Path to the game installation directory (can be overridden)
GAME_DIR="/home/$SERVICE_USER/$GAME_NAME"

# Path to the SteamCMD installation directory
STEAMCMD_DIR="/root"

# Name of the systemd service for the game (this is constructed from the GAME_NAME variable)
SERVICE_NAME="$GAME_NAME-server.service"

# Ports to be opened for the game (can be updated for other games as needed)
PORT_START="26900"
PORT_END="26905"

# Cron job schedule (default: run once a day at 3 AM)
CRON_SCHEDULE="0 3 * * *"

# ExecStart command to run the server (this is where the game-specific command goes)
EXEC_START="/home/$SERVICE_USER/$GAME_NAME/startserver.sh -configfile=/home/$SERVICE_USER/$GAME_NAME/serverconfig.xml"
```

## Pulling Updates

To pull the latest updates from the repository, navigate to the repository directory and run:

```bash
git pull origin main
```

This will fetch and merge the latest changes from the main branch of the repository.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

We welcome contributions from the community. To contribute, please follow these steps:

1. **Fork the repository** on GitHub.
2. **Clone your fork** to your local machine.
   ```bash
   git clone https://github.com/your-username/LinuxSteamGameServer.git
   ```
3. **Create a new branch** for your changes.
   ```bash
   git checkout -b feature/my-feature
   ```
4. **Make your changes** and commit them.
   ```bash
   git commit -m "Add a new feature"
   ```
5. **Push your changes** to your fork.
   ```bash
   git push origin feature/my-feature
   ```
6. **Open a pull request** to the main repository with a description of your changes.

## Reporting Issues

If you encounter any problems or bugs with the project, please open an issue on the [Issues page](https://github.com/jcphlux/LinuxSteamGameServer/issues).

Please include:
- A detailed description of the issue.
- Steps to reproduce the issue, if applicable.
- Any relevant error messages or logs.

## Feature Requests

If you'd like to suggest a new feature, please open a **Feature Request** issue. Provide as much detail as possible to help us understand the feature request.

## Support

If you need help with using or setting up the scripts, feel free to open an issue or reach out via discussions.

