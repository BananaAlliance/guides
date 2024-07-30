#!/bin/bash

GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
NC='\033[0m'  # No Color

echo -e "${BRIGHT_GREEN}-----------------------------------------------------------------------------${NC}"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo -e "${BRIGHT_GREEN}-----------------------------------------------------------------------------${NC}"

function print_step() {
  echo -e "${BRIGHT_GREEN}==================================================${NC}"
  echo -e "${GREEN}$1${NC}"
  echo -e "${BRIGHT_GREEN}==================================================${NC}"
}

# Функция для отображения анимированного спиннера
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

# Функция для отображения анимированного баннера
function print_banner() {
  echo -e "${GREEN}🌟🌟🌟 Добро пожаловать в установщик Infernet Node 🌟🌟🌟${NC}"
  sleep 1
  echo -e "${GREEN}Этот скрипт поможет вам установить и настроить все необходимые компоненты.${NC}"
  echo -e "${GREEN}Пожалуйста, следите за инструкциями на экране для лучшего опыта.${NC}"
  echo ""
}

# Обработка ошибок с подробным сообщением
function handle_error() {
  local step=$1
  echo -e "${BRIGHT_GREEN}⚠️ Произошла ошибка на этапе: '$step'${NC}"
  echo -e "${BRIGHT_GREEN}Пожалуйста, обратитесь в чат поддержки для помощи.${NC}"
  exit 1
}

# Функция для установки Forge
install_forge() {
  print_step "Установка Forge"
  curl -L https://foundry.paradigm.xyz | bash
  source /root/.bashrc
  foundryup
}

# Функция для проверки и установки Docker
install_docker() {
  print_step "Проверка и установка Docker"
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

# Функция для клонирования и настройки репозитория
setup_repository() {
  print_step "Настройка репозитория"
  if ! command -v jq &> /dev/null; then
    echo -e "${GREEN}jq не установлен. Попытка установить jq...${NC}"
    sudo apt-get update && sudo apt-get install -y jq || handle_error "Установка jq"
  fi

  cd $HOME
  rm -rf infernet-container-starter
  git clone --recurse-submodules https://github.com/ritual-net/infernet-container-starter || handle_error "Клонирование репозитория"

  docker_compose_file="/root/infernet-container-starter/deploy/docker-compose.yaml"

   # Изменение портов в docker-compose.yaml
  sed -i 's/8545:3000/8545:3051/' "$docker_compose_file"
  sed -i 's/--port 3000/--port 3051/' "$docker_compose_file"
  sed -i 's/3000:3000/3051:3051/' "$docker_compose_file"
  sed -i 's/--bind=0.0.0.0:3000/--bind=0.0.0.0:3051/' "$docker_compose_file"


  cd infernet-container-starter

  screen -ls | grep "ritual" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit
  screen -dmS ritual
  screen -S ritual -p 0 -X stuff "project=hello-world make deploy-container\n"
  sleep 15
}

# Функция для обновления файлов конфигурации
update_config_files() {
  print_step "Обновление файлов конфигурации"
  echo -e "${GREEN}Введите ваш приватный ключ:${NC}"
  read private_key
  sleep 10
  [[ "$private_key" != "0x"* ]] && private_key="0x$private_key"

  config_file="/root/infernet-container-starter/deploy/config.json"
  docker_compose_file="/root/infernet-container-starter/deploy/docker-compose.yaml"

   # Изменение портов в docker-compose.yaml
  sed -i 's/8545:3000/8545:3051/' "$docker_compose_file"
  sed -i 's/--port 3000/--port 3051/' "$docker_compose_file"
  sed -i 's/3000:3000/3051:3051/' "$docker_compose_file"
  sed -i 's/--bind=0.0.0.0:3000/--bind=0.0.0.0:3051/' "$docker_compose_file"

 


  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Порт успешно изменен на 3051 в файле docker-compose.yaml.${NC}"
  else
    echo -e "${GREEN}Произошла ошибка при изменении порта.${NC}"
  fi

  sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$config_file"
  sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"https://base-rpc.publicnode.com\",|" "$config_file"
  sed -i "s|\"private_key\":.*|\"private_key\": \"$private_key\"|" "$config_file"
  sed -i 's/"port": "3000"/"port": "3051"/' "$config_file"
  sed -i 's/--bind=0.0.0.0:3000/--bind=0.0.0.0:3051/' "$config_file"

   # Новое значение для поля "snapshot_sync"
  snapshot_sync_value='{"snapshot_sync": {"sleep": 5, "batch_size": 50}}'

    # Обновление или добавление поля "snapshot_sync" с помощью sed
  sed -i '/"snapshot_sync": {/c\'"$snapshot_sync_value" "$config_file"

  new_rpc_url="https://base-rpc.publicnode.com"
  sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|sender := .*|sender := $private_key|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile
  sed -i "/^# anvil's third default address$/,/^# deploying the contract$/s|RPC_URL := .*|RPC_URL := $new_rpc_url|" ~/infernet-container-starter/projects/hello-world/contracts/Makefile
  sed -i "s|address registry.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" ~/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol
}

# Функция для обновления порта в файле config.json
update_port() {
  print_step "Обновление порта в файле config.json"
  local config_file="/root/infernet-container-starter/deploy/config.json"
  if ! command -v jq &> /dev/null; then
    echo -e "${GREEN}jq не установлен. Попытка установить jq...${NC}"
    sudo apt-get update && sudo apt-get install -y jq || handle_error "Установка jq"
  fi

  echo -e "${GREEN}Начинаем обновление порта в конфигурационном файле.${NC}"
  local temp_file=$(mktemp)
  jq '.containers[] | select(.id == "hello-world") | .port = "3051" | .command = "--bind=0.0.0.0:3051 --workers=2"' "$config_file" > "$temp_file" && mv "$temp_file" "$config_file"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Порт успешно обновлен на 3051.${NC}"
  else
    echo -e "${GREEN}Произошла ошибка при обновлении порта.${NC}"
    return 1
  fi
  restart_docker_services
  echo -e "${GREEN}Обновление завершено.${NC}"
}

# Функция для развертывания и обновления конфигурации
deploy_and_update_config() {
  print_step "Развертывание и обновление конфигурации"
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

# Функция для настройки сервиса
setup_service() {
    print_step "Настройка сервиса"
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

# Функция для перезапуска Docker сервисов
restart_docker_services() {
    print_step "Перезапуск Docker сервисов"
    sleep 20
    docker restart infernet-anvil
    docker restart infernet-node
    docker restart hello-world
    docker restart deploy-node-1
    docker restart deploy-fluentbit-1
    docker restart deploy-redis-1
}

# Функция для обновления ноды
update_node() {
    print_step "Обновление ноды"
    cd ~/infernet-container-starter/deploy || handle_error "Переход в директорию"
    sed -i '5s/.*/    image: ritualnetwork\/infernet-node:1.0.0/' docker-compose.yaml
    docker compose down
    docker compose up
    echo -e "${GREEN}Нода успешно обновлена.${NC}"
}

# Функция для удаления ноды
uninstall_node() {
    print_step "Удаление ноды"
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

    docker kill infernet-anvil
    docker kill infernet-node
    docker kill hello-world
    docker kill deploy-node-1
    docker kill deploy-fluentbit-1
    docker kill deploy-redis-1

    echo -e "${GREEN}Нода успешно удалена.${NC}"
}

# Основная функция для установки ноды
install_node() {
    print_banner
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
    echo -e "${BRIGHT_GREEN}Использование: $0 {install | uninstall_node | update | update_port}${NC}"
    exit 1
    ;;
esac