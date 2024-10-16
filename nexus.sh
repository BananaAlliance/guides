#!/bin/bash

# Colors and Emojis
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CHECKMARK="\u2714"
ERROR="\u274C"
PROGRESS="\u23F3"
INSTALL="\u1F4E6"
SUCCESS="\u2728"
WARNING="\u26A0"
NODE="\u1F5A5"
INFO="\u2139"
SCRIPT_VERSION="1.0.0"

# Function to display the header
show_header() {
    clear
    echo -e "${MAGENTA}======================================${NC}"
    echo -e "${CYAN}       Nexus Node Installation Wizard (v${SCRIPT_VERSION})${NC}"
    echo -e "${MAGENTA}======================================${NC}"
    echo ""
}

# Function to display a separator
show_separator() {
    echo -e "${BLUE}--------------------------------------${NC}"
}

# Check if node is installed
is_node_installed() {
    if [ -d "$HOME/nexus/network-api" ]; then
        return 0
    else
        return 1
    fi
}

# Check if node is running
is_node_running() {
    if systemctl is-active --quiet nexus; then
        return 0
    else
        return 1
    fi
}

# View node logs
view_logs() {
    show_header
    echo -e "${NODE} ${GREEN}Displaying Nexus node logs...${NC}"
    show_separator
    sudo journalctl -u nexus -f
}

# Check for errors
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} ${RED}Execution failed. Please check the logs and try again.${NC}"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    show_header
    echo -e "${INSTALL} ${GREEN}Installing dependencies...${NC}"
    show_separator
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
    check_error
    echo -e "${INSTALL} ${GREEN}Installing Rust...${NC}"
    sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
    source $HOME/.cargo/env
    export PATH="$HOME/.cargo/bin:$PATH"
    rustup update
    check_error
    echo -e "${CHECKMARK} ${GREEN}Dependencies successfully installed.${NC}"
}

# Install Nexus node
install_node() {
    show_header
    read -p "Nexus is about to be installed. Do you want to continue? (y/n): " confirmation
    if [[ "$confirmation" != "y" ]]; then
        echo -e "${ERROR} ${RED}Installation cancelled by user.${NC}"
        exit 1
    fi
    echo -e "${NODE} ${GREEN}Installing Nexus node...${NC}"
    show_separator
    if [ -d "$HOME/nexus/network-api" ]; then
        echo -e "${INFO} ${YELLOW}Nexus is already installed. Updating...${NC}"
        (cd $HOME/nexus/network-api && git pull)
    else
        mkdir -p $HOME/nexus
        (cd $HOME/nexus && git clone https://github.com/nexus-xyz/network-api)
    fi
    (cd $HOME/nexus/network-api/clients/cli && cargo build --release)
    check_error
    create_service_file
    echo -e "${CHECKMARK} ${GREEN}Nexus node successfully installed.${NC}"
}

# Create systemd service file
create_service_file() {
    show_header
    echo -e "${INSTALL} ${GREEN}Creating service file for Nexus node...${NC}"
    show_separator

    NEXUS_PATH="$HOME/nexus/network-api/clients/cli/target/release/prover"

    sudo bash -c "cat << EOF > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Node
After=network.target

[Service]
User=$(whoami)
Environment=PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.cargo/bin
ExecStart=$NEXUS_PATH beta.orchestrator.nexus.xyz
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable nexus
    echo -e "${SUCCESS} ${GREEN}Service created and configured.${NC}"
}

# Node management menu
manage_node() {
    while true; do
        show_header
        echo -e "${NODE} ${YELLOW}Nexus Node Management Menu:${NC}"
        show_separator
        echo "1. Start Node ${CHECKMARK}"
        echo "2. Stop Node ${ERROR}"
        echo "3. Restart Node ${PROGRESS}"
        echo "4. View Logs ${INFO}"
        echo "5. Check Node Status ${INFO}"
        echo "6. Return to Main Menu ↩️"
        show_separator
        read -p "Select an option (1-6): " option

        case $option in
            1)
                sudo systemctl start nexus
                echo -e "${CHECKMARK} ${GREEN}Node started.${NC}"
                ;;
            2)
                sudo systemctl stop nexus
                echo -e "${CHECKMARK} ${GREEN}Node stopped.${NC}"
                ;;
            3)
                sudo systemctl restart nexus
                echo -e "${PROGRESS} ${GREEN}Node restarted.${NC}"
                ;;
            4)
                view_logs
                ;;
            5)
                if is_node_running; then
                    echo -e "${CHECKMARK} ${GREEN}Node is currently running.${NC}"
                else
                    echo -e "${ERROR} ${RED}Node is not running.${NC}"
                fi
                ;;
            6)
                return
                ;;
            *)
                echo -e "${ERROR} ${RED}Invalid choice!${NC}"
                ;;
        esac
        read -p "Press Enter to continue"
    done
}

# Main menu
main_menu() {
    while true; do
        show_header
        if is_node_installed; then
            echo -e "${SUCCESS} ${GREEN}Welcome to the Nexus Installation Wizard! (v${SCRIPT_VERSION})${NC}"
            show_separator

            if is_node_running; then
                echo "1. Manage Node ${NODE}"
                echo "2. Stop Node ${ERROR}"
                echo "3. View Logs ${INFO}"
                echo "4. Exit ${ERROR}"
            else
                echo "1. Start Node ${CHECKMARK}"
                echo "2. Delete Node ${ERROR}"
                echo "3. View Logs ${INFO}"
                echo "4. Exit ${ERROR}"
            fi
        else
            echo -e "${SUCCESS} ${GREEN}Node is not installed. Welcome to the Nexus Installation Wizard! (v${SCRIPT_VERSION})${NC}"
            show_separator
            echo "1. Install Node ${INSTALL}"
            echo "2. Exit ${ERROR}"
        fi
        show_separator
        read -p "Select an option: " choice

        case $choice in
            1)
                if is_node_installed; then
                    if is_node_running; then
                        manage_node
                    else
                        sudo systemctl start nexus
                        sleep 2
                        if is_node_running; then
                            echo -e "${CHECKMARK} ${GREEN}Nexus node successfully started.${NC}"
                        else
                            echo -e "${ERROR} ${RED}Failed to start the node. Please check the logs for more information.${NC}"
                        fi
                    fi
                else
                    install_dependencies
                    install_node
                fi
                ;;
            2)
                if is_node_installed; then
                    if is_node_running; then
                        sudo systemctl stop nexus
                        echo -e "${CHECKMARK} ${GREEN}Node stopped.${NC}"
                    else
                        sudo systemctl disable nexus
                        sudo rm -rf $HOME/nexus
                        sudo rm /etc/systemd/system/nexus.service
                        sudo systemctl daemon-reload
                        echo -e "${SUCCESS} ${GREEN}Nexus node successfully removed.${NC}"
                    fi
                else
                    echo -e "${SUCCESS} ${GREEN}Thank you for using the Nexus Installation Wizard!${NC}"
                    exit 0
                fi
                ;;
            3)
                view_logs
                ;;
            4)
                echo -e "${SUCCESS} ${GREEN}Thank you for using the Nexus Installation Wizard!${NC}"
                exit 0
                ;;
            *)
                echo -e "${ERROR} ${RED}Invalid choice!${NC}"
                ;;
        esac
        read -p "Press Enter to continue"
    done
}

# Self-update function
self_update() {
    REPO_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/nexus/nexus-wizzard.sh"

    REMOTE_VERSION=$(curl -s $REPO_URL | grep -Eo 'SCRIPT_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' | cut -d '"' -f 2)

    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${ERROR} ${RED}Failed to retrieve remote script version.${NC}"
        return 1
    fi

    if [ "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]; then
        read -p "A new version ($REMOTE_VERSION) is available. Do you want to update? (y/n): " update_confirmation
        if [[ "$update_confirmation" != "y" ]]; then
            echo -e "${WARNING} ${YELLOW}Update cancelled by user.${NC}"
            return 0
        fi

        echo -e "${WARNING} ${YELLOW}New version available ($REMOTE_VERSION). Updating...${NC}"

        TEMP_SCRIPT=$(mktemp)
        wget -O "$TEMP_SCRIPT" "$REPO_URL" || { echo -e "${ERROR} ${RED}Failed to download the update.${NC}"; return 1; }

        mv "$TEMP_SCRIPT" "$0" || { echo -e "${ERROR} ${RED}Failed to update script.${NC}"; return 1; }
        chmod +x "$0"

        echo -e "${CHECKMARK} ${GREEN}Script successfully updated to version $REMOTE_VERSION.${NC}"

        exec "$0" "$@"
    else
        echo -e "${CHECKMARK} ${GREEN}You already have the latest version (${SCRIPT_VERSION}).${NC}"
    fi
}

# Run self-update before launching main menu
self_update

# Launch main menu
main_menu
