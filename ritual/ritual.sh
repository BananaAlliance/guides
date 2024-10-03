#!/bin/bash

GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
NC='\033[0m'  # No Color

SCRIPT_VERSION="1.1.2"

echo -e "${BRIGHT_GREEN}-----------------------------------------------------------------------------${NC}"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo -e "${BRIGHT_GREEN}-----------------------------------------------------------------------------${NC}"

sudo apt install apt-transport-https ca-certificates curl software-properties-common build-essential -qy

function print_step() {
  echo -e "${BRIGHT_GREEN}==================================================${NC}"
  echo -e "${GREEN}$1${NC}"
  echo -e "${BRIGHT_GREEN}==================================================${NC}"
}

self_update() {
    # URL скрипта на GitHub
    REPO_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/ritual/rivalz.sh"

    # Получаем удаленную версию скрипта
    REMOTE_VERSION=$(curl -s $REPO_URL | grep -Eo 'SCRIPT_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' | cut -d '"' -f 2)

    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${ERROR} ${RED}Не удалось получить версию удаленного скрипта.${NC}"
        return 1
    fi

    if [ "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]; then
        echo -e "${WARNING} ${YELLOW}Доступна новая версия скрипта ($REMOTE_VERSION). Обновляем...${NC}"

        # Скачиваем новую версию во временный файл
        TEMP_SCRIPT=$(mktemp)
        wget -O "$TEMP_SCRIPT" "$REPO_URL" || { echo -e "${ERROR} ${RED}Не удалось загрузить обновление.${NC}"; return 1; }

        # Замена текущего скрипта на новый
        mv "$TEMP_SCRIPT" "$0" || { echo -e "${ERROR} ${RED}Не удалось обновить скрипт.${NC}"; return 1; }
        chmod +x "$0"

        echo -e "${CHECKMARK} ${GREEN}Скрипт успешно обновлен до версии $REMOTE_VERSION.${NC}"

        # Перезапускаем скрипт после обновления
        exec "$0" "$@"
    else
        echo -e "${CHECKMARK} ${GREEN}У вас уже установлена последняя версия скрипта (${SCRIPT_VERSION}).${NC}"
    fi
}


function spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\\'
  echo -n " "
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "${GREEN} [%c]  ${NC}" "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

function print_banner() {
  echo -e "${GREEN}🌟🌟🌟 Добро пожаловать в установщик Ritual Node 🌟🌟🌟${NC}"
  sleep 1
  echo -e "${GREEN}Этот скрипт поможет вам установить и настроить все необходимые компоненты.${NC}"
  echo -e "${GREEN}Пожалуйста, следите за инструкциями на экране для лучшего опыта.${NC}"
  echo ""
}

function handle_error() {
  local step=$1
  echo -e "${BRIGHT_GREEN}⚠️ Произошла ошибка на этапе: '$step'${NC}"
  echo -e "${BRIGHT_GREEN}Пожалуйста, обратитесь в чат поддержки для помощи.${NC}"
  exit 1
}

install_docker() {
  print_step "🐳 Проверка и установка Docker"
  if ! command -v docker &> /dev/null; then
    echo -e "${GREEN}🐳 Docker не найден, начинаем установку...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt -qy install curl git jq lz4 build-essential screen
    sudo apt install apt-transport-https ca-certificates curl software-properties-common build-essential -qy
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    sudo apt install docker-ce -qy
    echo -e "${GREEN}🐳 Docker успешно установлен.${NC}"
  else
    echo -e "${GREEN}🐳 Docker уже установлен.${NC}"
  fi
}

setup_repository() {
  print_step "📦 Настройка репозитория"
  if ! command -v jq &> /dev/null; then
    echo -e "${GREEN}jq не установлен. Попытка установить jq...${NC}"
    sudo apt-get update && sudo apt-get install -y jq || handle_error "Установка jq"
  fi

  cd $HOME
  rm -rf infernet-container-starter
  git clone --recurse-submodules https://github.com/ritual-net/infernet-container-starter || handle_error "Клонирование репозитория"

  cd infernet-container-starter

  screen -ls | grep "ritual" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit
  screen -dmS ritual
  screen -S ritual -p 0 -X stuff "project=hello-world make deploy-container\n"
  sleep 15
}

update_config_files() {
  print_step "🔧 Обновление файлов конфигурации"
  
  echo -e "${GREEN}Введите ваш приватный ключ:${NC}"
  read private_key
  sleep 10
  [[ "$private_key" != "0x"* ]] && private_key="0x$private_key"

  config_file="/root/infernet-container-starter/deploy/config.json"
  config_file_2="/root/infernet-container-starter/projects/hello-world/container/config.json"

  # Обновляем config_file
  sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$config_file"
  sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"https://base-rpc.publicnode.com\",|" "$config_file"
  sed -i "s|\"private_key\":.*|\"private_key\": \"$private_key\"|" "$config_file"

  snapshot_sync_value='{"snapshot_sync": {"sleep": 5, "batch_size": 50}}'
  sed -i '/"snapshot_sync": {/c\'"$snapshot_sync_value" "$config_file"

  # Обновляем config_file_2
  sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$config_file_2"
  sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"https://base-rpc.publicnode.com\",|" "$config_file_2"
  sed -i "s|\"private_key\":.*|\"private_key\": \"$private_key\"|" "$config_file_2"

  sed -i '/"snapshot_sync": {/c\'"$snapshot_sync_value" "$config_file_2"

  # Обновляем Makefile
  new_rpc_url="https://base-rpc.publicnode.com"
  sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|sender := .*|sender := $private_key|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile
  sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|RPC_URL := .*|RPC_URL := $new_rpc_url|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile

  # Обновляем Deploy.s.sol
  sed -i "s|address registry.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" ~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol
}

deploy_and_update_config() {
  print_step "🚀 Развертывание и обновление конфигурации"
  cd ~/infernet-container-starter
  output=$(make deploy-contracts project=hello-world 2>&1)
  echo "$output"
  contract_address=$(echo "$output" | grep -oP 'Deployed SaysHello:  \K[0-9a-fA-Fx]+')
  if [ -z "$contract_address" ]; then
    echo -e "${GREEN}Не удалось извлечь адрес контракта.${NC}"
    return 1
  else
    echo -e "${GREEN}Извлеченный адрес контракта: $contract_address${NC}"
  fi

  config_file="$HOME/infernet-container-starter/deploy/config.json"
  jq --arg addr "$contract_address" '.containers[0].allowed_addresses = [$addr]' "$config_file" > temp.json && mv temp.json "$config_file"
  solidity_file="$HOME/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"
  sed -i "s|SaysGM(.*);|SaysGM($contract_address);|" "$solidity_file"
  restart_docker_services
  echo -e "${GREEN}Solidity файл обновлен с новым адресом контракта.${NC}"
  make call-contract project=hello-world
}

setup_service() {
    print_step "🛠️ Настройка сервиса"
    local script_url="https://github.com/BananaAlliance/guides/raw/main/ritual/monitor_logs.sh"
    local script_path="/usr/local/bin/monitor_logs.sh"
    local service_path="/etc/systemd/system/monitor_logs.service"
    echo -e "${GREEN}Скачивание скрипта с GitHub...${NC}"
    curl -sL $script_url -o $script_path
    chmod +x $script_path
    echo -e "${GREEN}Создание systemd сервисного файла...${NC}"
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
    echo -e "${GREEN}Перезагрузка демона systemd...${NC}"
    systemctl daemon-reload
    echo -e "${GREEN}Включение и запуск сервиса...${NC}"
    systemctl enable monitor_logs
    systemctl start monitor_logs
    echo -e "${GREEN}Сервис успешно настроен и запущен.${NC}"
}

restart_docker_services() {
    print_step "🔄 Перезапуск Docker сервисов"
    sleep 20
    docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml down
    docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml up -d
}

update_node() {
    print_step "🔄 Обновление ноды"
    cd ~/infernet-container-starter/deploy || handle_error "Переход в директорию"
    docker compose down
    docker compose pull
    docker compose up -d
    echo -e "${GREEN}Нода успешно обновлена.${NC}"
}

uninstall_node() {
    print_step "🗑️ Удаление ноды"
    read -p "Вы уверены, что хотите удалить ноду Ritual? (y/n): " confirm
    if [[ $confirm != [yY] ]]; then
        echo -e "${GREEN}Удаление отменено.${NC}"
        return 0
    fi

    screen -ls | grep "ritual" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit
    rm -rf "$HOME/infernet-container-starter"
    sudo systemctl stop monitor_logs.service
    sudo systemctl disable monitor_logs.service
    sudo rm /etc/systemd/system/monitor_logs.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed

    docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml down -v

    echo -e "${GREEN}Нода успешно удалена.${NC}"
}

fix_docker_compose() {
    print_step "🔧 Исправление docker-compose"
    cd $HOME/infernet-container-starter/deploy || handle_error "Переход в директорию"
    
    docker compose down
    sleep 3
    sudo rm -rf docker-compose.yaml
    wget https://raw.githubusercontent.com/DOUBLE-TOP/guides/main/ritual/docker-compose.yaml
    docker compose up -d
    
    docker rm -fv infernet-anvil &>/dev/null
    
    echo -e "${GREEN}Docker-compose успешно исправлен.${NC}"
}

install_node() {
    print_banner
    echo -e "🚀 Начинаем установку Ritual Node..."
    echo -e "1. 🐳 Установка Docker"
    install_docker
    echo -e "2. 📦 Настройка репозитория"
    setup_repository
    echo -e "3. 🔧 Исправление docker-compose"
    fix_docker_compose
    echo -e "4. 🔧 Обновление файлов конфигурации"
    update_config_files
    echo -e "5. 🚀 Развертывание и обновление конфигурации"
    deploy_and_update_config
    echo -e "6. 🛠️ Настройка сервиса"
    setup_service
    echo -e "✅ Установка Ritual Node завершена!"
}

self_update

case "$1" in
  install)
    install_node
    ;;
  update)
    update_node
    ;;
  uninstall_node)
    uninstall_node
    ;;
  fix)
    fix_docker_compose
    ;;
  *)
    echo -e "${BRIGHT_GREEN}Использование: $0 {install | uninstall_node | update | fix}${NC}"
    echo -e "🚀 install        - Установить Ritual Node"
    echo -e "🔄 update         - Обновить ноду"
    echo -e "🗑️ uninstall_node - Удалить ноду"
    echo -e "🔧 fix            - Исправить docker-compose"
    exit 1
    ;;
esac