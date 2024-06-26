#!/bin/bash

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

# Определение цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

NC='\033[0m' # Без цвета

# Определение эмодзи
CHECK_MARK="\xE2\x9C\x85"
CROSS_MARK="\xE2\x9D\x8C"
INFO="\xE2\x84\xB9"

REPO="farcasterxyz/hub-monorepo"
RAWFILE_BASE="https://raw.githubusercontent.com/$REPO"
LATEST_TAG="@latest"
SCRIPT_FILE_PATH="scripts/hubble.sh"



install_jq() {
    if command -v jq >/dev/null 2>&1; then
        return 0
    fi

    echo "Installing jq..."

    # macOS
    if [[ "$(uname)" == "Darwin" ]]; then
        if command -v brew >/dev/null 2>&1; then
            brew install jq
        else
            echo "Homebrew is not installed. Please install Homebrew first."
            return 1
        fi

    # Ubuntu/Debian
    elif [[ -f /etc/lsb-release ]] || [[ -f /etc/debian_version ]]; then
        sudo apt-get update
        sudo apt-get install -y jq

    # RHEL/CentOS
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install -y jq

    # Fedora
    elif [[ -f /etc/fedora-release ]]; then
        sudo dnf install -y jq

    # openSUSE
    elif [[ -f /etc/os-release ]] && grep -q "ID=openSUSE" /etc/os-release; then
        sudo zypper install -y jq

    # Arch Linux
    elif [[ -f /etc/arch-release ]]; then
        sudo pacman -S jq

    else
        echo "Unsupported operating system. Please install jq manually."
        return 1
    fi

    echo "вњ… jq installed successfully."
}

# Fetch file from repo at "@latest"
fetch_file_from_repo() {
    local file_path="$1"
    local local_filename="$2"
    
    local download_url
    download_url="$RAWFILE_BASE/$LATEST_TAG/$file_path?t=$(date +%s)"

    # Download the file using curl, and save it to the local filename. If the download fails,
    # exit with an error.
    curl -sS -o "$local_filename" "$download_url" || { echo "Failed to fetch $download_url."; exit 1; }
}

do_bootstrap() {
    # Make the ~/hubble directory if it doesn't exist
    mkdir -p ~/hubble
    
    local tmp_file
    tmp_file=$(mktemp)
    fetch_file_from_repo "$SCRIPT_FILE_PATH" "$tmp_file"

    sed -i 's|local grafana_url="http://127.0.0.1:3000"|local grafana_url="http://127.0.0.1:3031"|' "$tmp_file"

    mv "$tmp_file" ~/hubble/hubble.sh
    chmod +x ~/hubble/hubble.sh

    # Run the hubble.sh script
    cd ~/hubble
    exec ./hubble.sh "upgrade" < /dev/tty
}

# Функция для проверки последнего изменения логов
check_log_updates() {
  local last_log_time=$(docker logs hubble-hubble-1 --tail 1 --since 1h --format '{{.Time}}' 2>&1 | tail -n 1)
  local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [[ -z "$last_log_time" ]]; then
    return 1
  fi

  last_log_epoch=$(date -d "$last_log_time" +%s)
  current_time_epoch=$(date -u +%s)
  time_difference=$((current_time_epoch - last_log_epoch))

  # Если последнее обновление было более 5 минут назад, считаем, что нода не работает
  if (( time_difference > 300 )); then
    return 1
  else
    return 0
  fi
}

# Функция для вывода статуса ноды
node_status() {
  echo -e "${INFO} ${YELLOW}Получение статуса...${NC}"
  
  log_output=$(docker logs hubble-hubble-1 --since 1m 2>&1)
  
  if echo "$log_output" | grep -q "Getting snapshot"; then
    echo -e "${BLUE} ${INFO} Нода синхронизируется...${NC}"
  elif check_log_updates; then
    echo -e "${GREEN} ${CHECK_MARK} Нода работает нормально${NC}"
  else
    echo -e "${RED} ${CROSS_MARK} Нода не работает${NC}"
  fi
}

# Функция для установки ноды
install_node() {
  echo -e "${INFO} ${YELLOW}Обновление системы...${NC}"
  sudo apt update -y && sudo apt upgrade -y

  echo -e "${INFO} ${YELLOW}Установка необходимых пакетов...${NC}"
  sudo apt install curl -y

  install_jq

  do_bootstrap

  # Получение внешнего IP и вывод ссылки на дашборд
  echo -e "${INFO} ${YELLOW}Получение внешнего IP...${NC}"
  external_ip=$(curl -s http://ipv4.icanhazip.com)
  echo -e "${CHECK_MARK} ${GREEN}Установка завершена!${NC}"
  echo -e "${INFO} ${YELLOW}Дашборд доступен по ссылке: http://${external_ip}:3031${NC}"
}


# Функция для обновления ноды
update_node() {
  echo -e "${INFO} ${YELLOW}Обновление ноды...${NC}"
  cd $HOME/hubble && ./hubble.sh upgrade
  echo -e "${CHECK_MARK} ${GREEN}Обновление завершено!${NC}"
}

# Функция для удаления ноды
remove_node() {
  read -p "Вы уверены, что хотите удалить ноду? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    echo -e "${INFO} ${YELLOW}Остановка Docker контейнера...${NC}"
    docker stop hubble-hubble-1

    echo -e "${INFO} ${YELLOW}Удаление директории hubble...${NC}"
    rm -rf $HOME/hubble

    echo -е "${CHECK_MARK} ${GREEN}Нода успешно удалена!${NC}"
  else
    echo -е "${CROSS_MARK} ${RED}Удаление ноды отменено.${NC}"
  fi
}

# Функция для просмотра логов
view_logs() {
  echo "Просмотр логов..."
  docker logs -f hubble-hubble-1 --since 1m
}

# Функция для вывода текущих значений RPC и FID
show_config() {
  echo -е "${YELLOW}Чтение конфигурационного файла...${NC}"
  if [ -f "$HOME/hubble/.env" ]; then
    source "$HOME/hubble/.env"
    echo -е "${YELLOW}Текущие значения:${NC}"
    echo -е "Ethereum Mainnet RPC URL: ${ETH_MAINNET_RPC_URL:-${RED}Не указано${NC}}"
    echo -е "Optimism Mainnet RPC URL: ${OPTIMISM_L2_RPC_URL:-${RED}Не указано${NC}}"
    echo -е "Farcaster FID: ${HUB_OPERATOR_FID:-${RED}Не указано${NC}}"
  else
    echo -е "${CROSS_MARK} ${RED}Конфигурационный файл не найден.${NC}"
  fi
}

# Функция для изменения значений RPC и FID
change_config() {
  read -p "Вы уверены, что хотите изменить значения RPC и FID? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    read -p "Введите новый Ethereum Mainnet RPC URL: " new_eth_rpc
    read -p "Введите новый Optimism Mainnet RPC URL: " new_opt_rpc
    read -p "Введите новый Farcaster FID: " new_farcaster_fid

    echo -е "${INFO} ${YELLOW}Изменение значений в конфигурационном файле...${NC}"
    if [ -f "$HOME/hubble/.env" ]; then
      sed -i "s|^ETH_MAINNET_RPC_URL=.*|ETH_MAINNET_RPC_URL=$new_eth_rpc|" "$HOME/hubble/.env"
      sed -i "s|^OPTIMISM_L2_RPC_URL=.*|OPTIMISM_L2_RPC_URL=$new_opt_rpc|" "$HOME/hubble/.env"
      sed -i "s|^HUB_OPERATOR_FID=.*|HUB_OPERATOR_FID=$new_farcaster_fid|" "$HOME/hubble/.env"
    else
      echo "ETH_MAINNET_RPC_URL=$new_eth_rpc" > "$HOME/hubble/.env"
      echo "OPTIMISM_L2_RPC_URL=$new_opt_rpc" >> "$HOME/hubble/.env"
      echo "HUB_OPERATOR_FID=$new_farcaster_fid" >> "$HOME/hubble/.env"
    fi

    echo -е "${CHECK_MARK} ${GREEN}Значения успешно изменены!${NC}"
    show_config

    $HOME/hubble/hubble.sh down

    $HOME/hubble/hubble.sh up
  else
    echo -е "${CROSS_MARK} ${RED}Изменение значений отменено.${NC}"
  fi
}
# Функция для запроса нового FID и замены его в файле .env
change_fid() {
  local env_file="$HOME/hubble/.env"

  # Проверка существования файла .env
  if [ ! -f "$env_file" ]; then
    echo -e "${CROSS_MARK} ${RED}Файл .env не найден.${NC}"
    return 1
  fi

  # Запрос нового FID у пользователя
  read -p "Введите новый Farcaster FID: " new_fid

  # Проверка валидности введенного FID
  if ! [[ "$new_fid" =~ ^[0-9]+$ ]]; then
    echo -e "${CROSS_MARK} ${RED}Неверный формат FID. Пожалуйста, введите число.${NC}"
    return 1
  fi

  # Замена старого FID на новый в файле .env
  sed -i "s/^HUB_OPERATOR_FID=.*/HUB_OPERATOR_FID=$new_fid/" "$env_file"
  echo -e "${CHECK_MARK} ${GREEN}FID успешно обновлен в файле .env!${NC}"

  # Перезапуск ноды
  echo -e "${INFO} ${YELLOW}Перезапуск ноды...${NC}"
  docker stop hubble-hubble-1
  cd ~/hubble
  exec ./hubble.sh "upgrade" < /dev/tty
}


# Функция для перезапуска ноды
restart_node() {
  echo -e "${INFO} ${YELLOW}Перезапуск ноды...${NC}"
  docker stop hubble-hubble-1
  cd ~/hubble
  exec ./hubble.sh "upgrade" < /dev/tty
  echo -e "${CHECK_MARK} ${GREEN}Нода успешно перезапущена!${NC}"
}

# Добавление новой опции в case
case "$1" in
  install)
    install_node
    ;;
  update)
    update_node
    ;;
  remove)
    remove_node
    ;;
  logs)
    view_logs
    ;;
  show-config)
    show_config
    ;;
  change-config)
    change_config
    ;;
  change-fid)
    change_fid
    ;;
  restart)
    restart_node
    ;;
  status)
    node_status
    ;;  
  *)
    echo "Использование: {install|update|remove|logs|show-config|change-config|change-fid|restart}"
    ;;
esac