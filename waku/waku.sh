#!/bin/bash

# Настройка цветов для вывода
GREEN="\e[32m"
RED="\e[39m"
NORMAL="\e[0m"

# Проверка, установлена ли уже нода
function check_node_installed {
  if [ -d "$HOME/nwaku-compose" ]; then
    echo -e "${RED}Нода уже установлена.${NORMAL}"
    read -p "Вы хотите удалить и заново установить ноду? (y/n): " choice
    case "$choice" in
      y|Y )
        echo "Остановка контейнеров..."
        cd "$HOME/nwaku-compose" || { echo "Не удалось перейти в директорию nwaku-compose. Прекращение работы."; exit 1; }
        docker-compose down || { echo "Не удалось остановить контейнеры. Прекращение работы."; exit 1; }
        
        echo "Удаление старой версии ноды..."
        rm -rf "$HOME/nwaku-compose" || { echo "Не удалось удалить директорию nwaku-compose. Прекращение работы."; exit 1; }
        
        echo "Старая версия ноды удалена. Начинается новая установка..."
        ;;
      n|N )
        echo "Выход из установки."
        exit 1
        ;;
      * )
        echo "Неверный выбор. Выход из установки."
        exit 1
        ;;
    esac
  fi
}


# Проверка, установлены ли необходимые пакеты
function check_tools_installed {
  for tool in mc wget htop jq git; do
    if ! dpkg -l | grep -qw $tool; then
      return 1
    fi
  done
  return 0
}

# Установка необходимых инструментов
function install_tools {
  if check_tools_installed; then
    echo -e "${GREEN}Все необходимые пакеты уже установлены.${NORMAL}"
  else
    sudo apt update && sudo apt install mc wget htop jq git -y
  fi
}

# Установка Docker
function install_docker {
  if ! command -v docker &> /dev/null; then
    curl -s https://get.docker.com | bash
  else
    echo -e "${GREEN}Docker уже установлен.${NORMAL}"
  fi
}

# Установка и настройка ufw
function install_ufw {
  if ! command -v ufw &> /dev/null; then
    sudo apt install ufw -y
    sudo ufw allow OpenSSH
    sudo ufw --force enable
  else
    echo -e "${GREEN}UFW уже установлен и настроен.${NORMAL}"
  fi
}

# Запрос данных от пользователя
function prompt_for_inputs {
  read -p "Введите ваш RPC Sepolia https URL (например, https://sepolia.infura.io/v3/ВАШ_КЛЮЧ или https://eth-sepolia.g.alchemy.com/v2/ВАШ_КЛЮЧ): " RPC_URL
  read -p "Введите ваш приватный ключ ETH кошелька (не менее 0.1 ETH в сети Sepolia): " WAKU_PRIVATE_KEY
  read -p "Введите пароль для настройки ноды: " WAKU_PASS
}

# Клонирование репозитория и настройка окружения
function setup_environment {
  git clone https://github.com/waku-org/nwaku-compose
  cd nwaku-compose
  cp .env.example .env

  sed -i "s|ETH_CLIENT_ADDRESS=.*|ETH_CLIENT_ADDRESS=$RPC_URL|" .env
  sed -i "s|ETH_TESTNET_KEY=.*|ETH_TESTNET_KEY=$WAKU_PRIVATE_KEY|" .env
  sed -i "s|RLN_RELAY_CRED_PASSWORD=.*|RLN_RELAY_CRED_PASSWORD=$WAKU_PASS|" .env

  # Изменение порта графаны
  sed -i 's/0\.0\.0\.0:3000:3000/0.0.0.0:3030:3000/g' docker-compose.yml

  bash register_rln.sh
}

# Запуск docker контейнеров
function start_docker_containers {
  cd $HOME/nwaku-compose
  docker compose -f docker-compose.yml up -d
}

# Остановка и удаление docker контейнеров
function stop_docker_containers {
  cd $HOME/nwaku-compose
  docker compose -f docker-compose.yml down
}

# Перезапуск docker контейнеров
function restart_docker_containers {
  cd $HOME/nwaku-compose
  docker compose -f docker-compose.yml restart
}

# Просмотр логов docker контейнеров
function view_logs {
  cd $HOME/nwaku-compose
  docker compose -f docker-compose.yml logs -f --tail=100
}

# Вывод информации о доступных командах
function display_usage_info {
  ip_address=$(hostname -I | awk '{print $1}')
  echo -e "${GREEN}Команды для управления нодой Waku:${NORMAL}"
  echo -e "${RED}Использование: $0 {install|remove|start|stop|restart|logs|info}${NORMAL}"
  echo -e "${GREEN}start: Запуск ноды Waku.${NORMAL}"
  echo -e "${GREEN}stop: Остановка ноды Waku.${NORMAL}"
  echo -e "${GREEN}restart: Перезапуск ноды Waku.${NORMAL}"
  echo -e "${GREEN}logs: Просмотр логов ноды Waku.${NORMAL}"
  echo -e "${GREEN}info: Вывод информации о доступных командах.${NORMAL}"
  echo -e "${GREEN}Дашборд графаны доступен по ссылке: http://$ip_address:3030/d/yns_4vFVk/nwaku-monitoring${NORMAL}"
}

# Основной процесс установки
function install_node {
  check_node_installed
  prompt_for_inputs
  install_tools
  install_ufw
  install_docker
  setup_environment
  start_docker_containers
  display_usage_info
}

# Основной процесс удаления
function remove_node {
  if [ -d "$HOME/nwaku-compose" ]; then
    stop_docker_containers
    rm -rf $HOME/nwaku-compose
    echo -e "${GREEN}Нода успешно удалена.${NORMAL}"
  else
    echo -e "${RED}Нода не установлена.${NORMAL}"
  fi
}

# Основной процесс вывода информации
function info_node {
  if [ -d "$HOME/nwaku-compose" ]; then
    display_usage_info
  else
    echo -e "${RED}Нода не установлена.${NORMAL}"
  fi
}

# Разбор аргументов командной строки
case "$1" in
  install)
    install_node
    ;;
  remove)
    remove_node
    ;;
  start)
    start_docker_containers
    ;;
  stop)
    stop_docker_containers
    ;;
  restart)
    restart_docker_containers
    ;;
  logs)
    view_logs
    ;;
  info)
    info_node
    ;;
  *)
    echo -e "${RED}Использование: $0 {install|remove|start|stop|restart|logs|info}${NORMAL}"
    exit 1
    ;;
esac

