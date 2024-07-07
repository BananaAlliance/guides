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
        sudo apt install apt-transport-https ca-certificates curl software-properties-common build-essential -qy
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
        sudo apt install docker-ce -qy
    else
        echo "Docker is already installed."
    fi
}

# Function to clone and set up the repository
setup_repository() {
    # Проверяем, установлен ли jq
    if ! command -v jq &> /dev/null; then
        echo "jq не установлен. Попытка установить jq..."
        # Попытка установить jq с помощью менеджера пакетов apt (для Debian/Ubuntu)
        sudo apt-get update && sudo apt-get install -y jq
        if [ $? -ne 0 ]; then
            echo "Не удалось установить jq. Пожалуйста, установите jq вручную."
            return 1
        fi
    fi

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
    sleep 10
    [[ "$private_key" != "0x"* ]] && private_key="0x$private_key"

    config_file="/root/infernet-container-starter/deploy/config.json"


    sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$config_file"
    sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"https://base-rpc.publicnode.com\",|" "$config_file"
    sed -i "s|\"private_key\":.*|\"private_key\": \"$private_key\"|" "$config_file"

    # Изменение порта в строке port и в строке command
    sed -i 's/"port": "3000"/"port": "3051"/' "$config_file"
    sed -i 's/--bind=0.0.0.0:3000/--bind=0.0.0.0:3051/' "$config_file"

    new_rpc_url="https://base-rpc.publicnode.com"

    # Обновление файла Makefile
    sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|sender := .*|sender := $private_key|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile
    sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|RPC_URL := .*|RPC_URL := $new_rpc_url|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile


  
    # Update ~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol
    sed -i "s|address registry.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" ~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol
}

# Функция для обновления порта в файле config.json
update_port() {
    # Определяем путь к файлу config.json
    local config_file="/root/infernet-container-starter/deploy/config.json"
    
    # Проверяем, установлен ли jq
    if ! command -v jq &> /dev/null; then
        echo "jq не установлен. Попытка установить jq..."
        # Попытка установить jq с помощью менеджера пакетов apt (для Debian/Ubuntu)
        sudo apt-get update && sudo apt-get install -y jq
        if [ $? -ne 0 ]; then
            echo "Не удалось установить jq. Пожалуйста, установите jq вручную."
            return 1
        fi
    fi

    echo "Начинаем обновление порта в конфигурационном файле."

    # Временный файл для хранения результатов
    local temp_file=$(mktemp)

    # Обновляем порт и команду для контейнера hello-world
    jq '.containers[] | select(.id == "hello-world") | .port = "3051" | .command = "--bind=0.0.0.0:3051 --workers=2"' "$config_file" > "$temp_file" && mv "$temp_file" "$config_file"
    
    # Проверяем, успешно ли был обновлен файл
    if [ $? -eq 0 ]; then
        echo "Порт успешно обновлен на 3051."
    else
        echo "Произошла ошибка при обновлении порта."
        return 1
    fi
    
    restart_docker_services

    echo "Обновление завершено."
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

    restart_docker_services

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
    docker restart infernet-anvil
    docker restart infernet-node
    docker restart hello-world
    docker restart deploy-node-1
    docker restart deploy-fluentbit-1
    docker restart deploy-redis-1
}

update_node() {
    # Перейти в нужную директорию
    cd ~/infernet-container-starter/deploy || { echo "Не удалось перейти в директорию"; return 1; }

    # Обновить файл docker-compose.yaml
    sed -i '5s/.*/    image: ritualnetwork\/infernet-node:1.0.0/' docker-compose.yaml

    # Остановить Docker Compose
    docker compose down

    # Запустить Docker Compose
    docker compose up

    echo "Нода успешно обновлена."
}

uninstall_node() {
    # Спросить подтверждение удаления
    read -p "Вы уверены, что хотите удалить ноду Ritual? (y/n): " confirm
    if [[ $confirm != [yY] ]]; then
        echo "Удаление отменено."
        return 0
    fi

    # Закрыть сессию "ritual"
    screen -ls | grep "ritual" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit

    # Удалить директорию $HOME/infernet-container-starter
    rm -rf "$HOME/infernet-container-starter"

    # Остановить и удалить сервис monitor_logs.service
    sudo systemctl stop monitor_logs.service
    sudo systemctl disable monitor_logs.service
    sudo rm /etc/systemd/system/monitor_logs.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed

    docker kill infernet-anvil
    docker kill infernet-node
    docker kill hello-world
    docker kill deploy-node-1
    docker kill deploy-fluentbit-1
    docker kill deploy-redis-1

    echo "Нода успешно удалена."
}

# Main function to control script flow
install_node() {
    #install_forge
    install_docker
    setup_repository
    update_config_files
    deploy_and_update_config
    setup_service
}


# Обработка аргументов
case "$1" in
    install)
        install_node
        ;;
   update_port)
        update_port
        ;;
   update) 
        update_node
        ;;
   uninstall_node)
        uninstall_node
        ;;
    *)
        echo "Usage: $0 {install | uninstall_node | update | update_port}"
        exit 1
        ;;
esac
