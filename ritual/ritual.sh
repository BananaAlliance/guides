#!/bin/bash

# Function to install Forge
install_forge() {
    echo "Installing Forge..."
    curl -L https://foundry.paradigm.xyz | bash
    source /root/.bashrc
    foundryup
}

# Function to check and install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker could not be found, installing..."
        sudo apt update && sudo apt upgrade -y
        sudo apt -qy install curl git jq lz4 build-essential screen
        sudo apt install apt-transport-https ca-certificates curl software-properties-common -qy
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
        sudo apt install docker-ce -qy
    else
        echo "Docker is already installed."
    fi
}

# Function to clone and set up the repository
setup_repository() {
    cd $HOME
    echo "Removing any existing repository directory..."
    rm -rf infernet-container-starter

    echo "Cloning the repository with submodules..."
    git clone --recurse-submodules https://github.com/ritual-net/infernet-container-starter

    cd infernet-container-starter

    echo "Closing any existing screen sessions named 'ritual'..."
    screen -ls | grep "ritual" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit

    echo "Creating a new detached screen session named 'ritual'..."
    screen -dmS ritual

    echo "Sending command to the new screen session..."
    screen -S ritual -p 0 -X stuff "project=hello-world make deploy-container\n"

    sleep 15
}

# Function to update configuration files
update_config_files() {
    echo "Updating configuration files..."

    local private_key
    echo "Enter your private key:"
    read private_key
    [[ "$private_key" != "0x"* ]] && private_key="0x$private_key"

    local config_file="$HOME/infernet-container-starter/deploy/config.json"
    local new_rpc_url="https://base-rpc.publicnode.com"
    local coordinator_address="0x8d871ef2826ac9001fb2e33fdd6379b6aabf449c"

    jq --arg pk "$private_key" --arg rpc "$new_rpc_url" --arg ca "$coordinator_address" \
       '.coordinator_address = $ca | .rpc_url = $rpc | .private_key = $pk' \
       "$config_file" > temp.json && mv temp.json "$config_file"

    local makefile="$HOME/infernet-container-starter/projects/hello-world/contracts/Makefile"
    sed -i "s|sender := .*|sender := $private_key|" "$makefile"
    sed -i "s|RPC_URL := .*|RPC_URL := $new_rpc_url|" "$makefile"

    local deploy_sol="$HOME/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol"
    sed -i "s|address coordinator.*|address coordinator = $coordinator_address;|" "$deploy_sol"
}

# Function to deploy contracts and update configuration
deploy_and_update_config() {
    cd ~/infernet-container-starter
    echo "Deploying contracts and updating configuration..."

    local output=$(make deploy-contracts project=hello-world 2>&1)
    echo "$output"

    local contract_address=$(echo "$output" | grep -oP 'Deployed SaysHello:  \K[0-9a-fA-Fx]+')
    if [ -z "$contract_address" ]; then
        echo "Failed to extract contract address."
        return 1
    fi

    echo "Extracted contract address: $contract_address"

    local config_file="$HOME/infernet-container-starter/deploy/config.json"
    jq --arg addr "$contract_address" '.containers[0].allowed_addresses = [$addr]' "$config_file" > temp.json && mv temp.json "$config_file"

    local solidity_file="$HOME/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"
    sed -i "s|SaysGM(.*);|SaysGM($contract_address);|" "$solidity_file"

    echo "Updated Solidity file with the new contract address."
    make call-contract project=hello-world
}

# Function to set up the service
setup_service() {
    local script_url="https://github.com/BananaAlliance/guides/raw/main/ritual/monitor_logs.sh"
    local script_path="/usr/local/bin/monitor_logs.sh"
    local service_path="/etc/systemd/system/monitor_logs.service"
    local service_name="monitor_logs"

    if systemctl list-units --full -all | grep -Fq "$service_name.service"; then
        echo "Service $service_name already exists. Exiting setup."
        return 1
    fi

    echo "Downloading the script from GitHub..."
    if ! curl -sL "$script_url" -o "$script_path"; then
        echo "Failed to download the script. Exiting setup."
        return 1
    fi

    chmod +x "$script_path"

    echo "Creating systemd service file..."
    cat <<EOF > "$service_path"
[Unit]
Description=Monitor Logs and Manage Docker Containers
After=network.target

[Service]
Type=simple
User=root
ExecStart=$script_path
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    if [ ! -f "$service_path" ]; then
        echo "Failed to create the service file. Exiting setup."
        return 1
    fi

    echo "Reloading systemd daemon..."
    if ! systemctl daemon-reload; then
        echo "Failed to reload systemd daemon. Exiting setup."
        return 1
    fi

    echo "Enabling and starting the service..."
    if ! systemctl enable "$service_name"; then
        echo "Failed to enable the service. Exiting setup."
        return 1
    fi

    if ! systemctl start "$service_name"; then
        echo "Failed to start the service. Exiting setup."
        return 1
    fi

    echo "Service has been set up and started successfully."
}

# Function to restart Docker services
restart_docker_services() {
    sleep 20
    docker restart anvil-node
    docker restart hello-world
    docker restart deploy-node-1
    docker restart deploy-fluentbit-1
    docker restart deploy-redis-1
}

# Main function to control script flow
main() {
    install_docker
    setup_repository
    update_config_files
    deploy_and_update_config
    setup_service
    restart_docker_services
}

# Execute the main function
main
