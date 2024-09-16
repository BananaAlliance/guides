#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # Сброс цвета

LOG_FILE="$HOME/processed.log"
CONFIG_FILE="wallets.conf"

# Функция для красивого вывода шагов
print_step() {
    echo -e "\n${BRIGHT_GREEN}🚀 ${1}${NC}"
    echo -e "${BRIGHT_GREEN}$(printf '=%.0s' {1..50})${NC}\n"
}

# Функция для отображения прогресса
show_progress() {
    local duration=$1
    local sleep_interval=0.1
    local progress=0
    local bar_length=40

    while [ $progress -lt 100 ]; do
        echo -ne "\r[${YELLOW}"
        for ((i=0; i<bar_length; i++)); do
            if [ $i -lt $((progress * bar_length / 100)) ]; then
                echo -n "▓"
            else
                echo -n "░"
            fi
        done
        echo -ne "${NC}] ${progress}%"
        progress=$((progress + 1))
        sleep $sleep_interval
    done
    echo -ne "\r[${YELLOW}$(printf '▓%.0s' $(seq 1 $bar_length))${NC}] 100%\n"
}

# Функция для обработки ошибок
handle_error() {
    echo -e "\n${YELLOW}⚠️ Ошибка: ${1}${NC}"
    echo -e "${YELLOW}Пожалуйста, обратитесь в поддержку для помощи.${NC}"
    exit 1
}

# Функция для установки необходимых компонентов
install_dependencies() {
    print_step "Установка необходимых компонентов"
    
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl git jq lz4 build-essential screen apt-transport-https ca-certificates software-properties-common

    if ! command -v docker &> /dev/null; then
        echo -e "${BLUE}🐳 Установка Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "${BLUE}🐳 Установка Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi

    echo -e "${GREEN}✅ Все необходимые компоненты установлены.${NC}"
}

# Функция для настройки репозитория
setup_repository() {
    print_step "Настройка репозитория"

    local repo_dir="$HOME/infernet-container-starter"
    if [ -d "$repo_dir" ]; then
        echo -e "${BLUE}📂 Обновление существующего репозитория...${NC}"
        cd "$repo_dir" && git pull
    else
        echo -e "${BLUE}📥 Клонирование репозитория...${NC}"
        git clone --recurse-submodules https://github.com/ritual-net/infernet-container-starter "$repo_dir"
    fi

    cd "$repo_dir" || handle_error "Не удалось перейти в директорию репозитория"

    local docker_compose_file="$repo_dir/deploy/docker-compose.yaml"
    sed -i 's/8545:3000/8545:3051/; s/--port 3000/--port 3051/; s/3000:3000/3051:3051/; s/--bind=0.0.0.0:3000/--bind=0.0.0.0:3051/' "$docker_compose_file"

    echo -e "${GREEN}✅ Репозиторий настроен успешно.${NC}"
}

# Функция для обновления конфигурационных файлов
update_config_files() {
    local wallet=$1
    local private_key=$2
    [[ "$private_key" != "0x"* ]] && private_key="0x$private_key"

    print_step "Обновление конфигурации для кошелька $wallet"

    local config_file="$HOME/infernet-container-starter/deploy/config.json"
    local docker_compose_file="$HOME/infernet-container-starter/deploy/docker-compose.yaml"

    # Обновление config.json
    jq --arg pk "$private_key" --arg rpc "https://base-rpc.publicnode.com" '
        .private_key = $pk |
        .rpc_url = $rpc |
        .registry_address = "0x3B1554f346DFe5c482Bb4BA31b880c1C18412170" |
        .port = "3051" |
        .snapshot_sync = {"sleep": 5, "batch_size": 50}
    ' "$config_file" > tmp.json && mv tmp.json "$config_file"

    # Обновление Makefile
    sed -i "s|sender := .*|sender := $private_key|; s|RPC_URL := .*|RPC_URL := https://base-rpc.publicnode.com|" "$HOME/infernet-container-starter/projects/hello-world/contracts/Makefile"

    # Обновление Deploy.s.sol
    sed -i "s|address registry.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" "$HOME/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol"

    echo -e "${GREEN}✅ Конфигурационные файлы обновлены.${NC}"
}

# Функция для развертывания и обновления конфигурации
deploy_and_update_config() {
    print_step "Развертывание контракта и обновление конфигурации"

    cd "$HOME/infernet-container-starter" || handle_error "Не удалось перейти в директорию проекта"
    
    echo -e "${BLUE}🚀 Развертывание контракта...${NC}"
    output=$(make deploy-contracts project=hello-world 2>&1)
    contract_address=$(echo "$output" | grep -oP 'Deployed SaysHello:  \K[0-9a-fA-Fx]+')

    if [ -z "$contract_address" ]; then
        handle_error "Не удалось извлечь адрес контракта"
    fi

    echo -e "${GREEN}✅ Контракт развернут по адресу: $contract_address${NC}"

    local config_file="$HOME/infernet-container-starter/deploy/config.json"
    jq --arg addr "$contract_address" '.containers[0].allowed_addresses = [$addr]' "$config_file" > tmp.json && mv tmp.json "$config_file"

    local solidity_file="$HOME/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"
    sed -i "s|SaysGM(.*);|SaysGM($contract_address);|" "$solidity_file"

    echo -e "${BLUE}🔄 Перезапуск Docker сервисов...${NC}"
    docker-compose down && docker-compose up -d

    echo -e "${BLUE}📞 Вызов контракта...${NC}"
    make call-contract project=hello-world

    echo -e "${GREEN}✅ Конфигурация обновлена и контракт вызван.${NC}"
}

# Функция для обработки каждого кошелька
process_wallet() {
    local wallet=$1
    local private_key=$2

    print_step "Обработка кошелька: $wallet"

    update_config_files "$wallet" "$private_key"
    deploy_and_update_config

    echo "$wallet обработан." >> "$LOG_FILE"
    echo -e "${GREEN}✅ Кошелек $wallet успешно обработан.${NC}"
}

# Основная функция
main() {
    echo -e "${BRIGHT_GREEN}
    ╔═════════════════════════════════════════════════╗
    ║   Добро пожаловать в SDS Ritual Node Installer  ║
    ╚═════════════════════════════════════════════════╝${NC}"

    install_dependencies
    setup_repository

    print_step "Обработка кошельков"

    while IFS=: read -r wallet private_key; do
        if [[ -n "$wallet" && ! $(grep "$wallet" "$LOG_FILE") ]]; then
            process_wallet "$wallet" "$private_key"
        else
            echo -e "${YELLOW}ℹ️ Кошелек $wallet уже обработан. Пропуск...${NC}"
        fi
    done < "$CONFIG_FILE"

    echo -e "\n${BRIGHT_GREEN}🎉 Все операции завершены успешно!${NC}"
}

# Запуск основного процесса
main
