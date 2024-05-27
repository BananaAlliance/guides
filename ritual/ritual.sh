#!/bin/bash

# Function to install Forge
install_forge() {
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
    # Удаляем предыдущую директорию проекта, если она существует
    rm -rf infernet-container-starter

    # Клонируем репозиторий с подмодулями
    git clone --recurse-submodules https://github.com/ritual-net/infernet-container-starter

    # Переходим в директорию проекта
    cd infernet-container-starter

    # Закрываем все существующие сессии screen с именем 'ritual'
    screen -ls | grep "ritual" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit

    # Создаем новую детачированную сессию screen с именем 'ritual'
    screen -dmS ritual

    # Отправляем команду в только что созданную сессию screen
    screen -S ritual -p 0 -X stuff "project=hello-world make deploy-container\n"

    sleep 15

}



# Function to update configuration files
update_config_files() {
    # Update ~/infernet-container-starter/deploy/config.json
    local private_key
    echo "Enter your private key:"
    read private_key
    [[ "$private_key" != "0x"* ]] && private_key="0x$private_key"
    sed -i "s|\"coordinator_address\":.*|\"coordinator_address\": \"0x8d871ef2826ac9001fb2e33fdd6379b6aabf449c\",|" ~/infernet-container-starter/deploy/config.json
    sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"https://base-rpc.publicnode.com\",|" ~/infernet-container-starter/deploy/config.json
    sed -i "s|\"private_key\":.*|\"private_key\": \"$private_key\"|" ~/infernet-container-starter/deploy/config.json

    new_rpc_url="https://base-rpc.publicnode.com"

    # Обновление файла Makefile
    sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|sender := .*|sender := $private_key|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile
    sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|RPC_URL := .*|RPC_URL := $new_rpc_url|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile


  
    # Update ~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol
    sed -i "s|address coordinator.*|address coordinator = 0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c;|" ~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol
}
function deploy_and_update_config {
    # Переходим в каталог проекта
    cd ~/infernet-container-starter

    # Выполняем сборку и деплой контрактов, сохраняем вывод в переменную
    output=$(make deploy-contracts project=hello-world 2>&1)

    # Выводим весь процесс в терминал для отладки
    echo "$output"

    # Извлекаем адрес контракта из вывода
    contract_address=$(echo "$output" | grep -oP 'Deployed SaysHello:  \K[0-9a-fA-Fx]+')

    # Проверяем, был ли адрес успешно извлечен
    if [ -z "$contract_address" ]; then
        echo "Failed to extract contract address."
        return 1
    else
        echo "Extracted contract address: $contract_address"
    fi

    # Файл конфигурации, который нужно обновить
    config_file="$HOME/infernet-container-starter/deploy/config.json"

    # Обновляем файл конфигурации JSON
    jq --arg addr "$contract_address" '.containers[0].allowed_addresses = [$addr]' "$config_file" > temp.json && mv temp.json "$config_file"

    # Путь к файлу Solidity, который нужно обновить
    solidity_file="$HOME/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"

    # Обновляем адрес контракта в Solidity скрипте
    sed -i "s|SaysGM(.*);|SaysGM($contract_address);|" "$solidity_file"

    echo "Updated Solidity file with the new contract address."

    make call-contract project=hello-world
}

setup_service() {
    # Задаем переменные
    local script_url="https://github.com/BananaAlliance/guides/raw/main/ritual/monitor_logs.sh"
    local script_path="/usr/local/bin/monitor_logs.sh"
    local service_path="/etc/systemd/system/monitor_logs.service"

    # Скачивание скрипта
    echo "Downloading the script from GitHub..."
    curl -sL $script_url -o $script_path

    # Даем скрипту права на выполнение
    chmod +x $script_path

    # Создание сервисного файла для systemd
    echo "Creating systemd service file..."
    cat <<EOF > $service_path
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

    # Перезагрузка systemd для применения изменений
    echo "Reloading systemd daemon..."
    systemctl daemon-reload

    # Включение и запуск сервиса
    echo "Enabling and starting the service..."
    systemctl enable monitor_logs
    systemctl start monitor_logs

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
    #install_forge
    install_docker
    setup_repository
    update_config_files
    deploy_and_update_config
    setup_service
}

# Execute the main function
main
