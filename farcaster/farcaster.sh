#!/bin/bash

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

  echo -e "${INFO} ${YELLOW}Установка screen...${NC}"
  sudo apt install screen -y

  read -p "Введите Ethereum Mainnet RPC URL: " eth_rpc
  read -p "Введите Optimism Mainnet RPC URL: " opt_rpc
  read -p "Введите Farcaster FID: " farcaster_fid

  # Закрытие существующей сессии screen, если есть
  echo -e "${INFO} ${YELLOW}Закрытие существующей сессии screen...${NC}"
  screen -S farcaster -X quit

  # Создание новой сессии screen и запуск скрипта
  echo -e "${INFO} ${YELLOW}Создание новой сессии screen и запуск скрипта...${NC}"
  screen -dmS farcaster bash -c "curl -sSL https://download.thehubble.xyz/bootstrap.sh | bash"

  # Отправка ввода в сессию screen
  echo -e "${INFO} ${YELLOW}Отправка данных в сессию screen...${NC}"
  screen -S farcaster -p 0 -X stuff "$eth_rpc$(printf \\r)"
  screen -S farcaster -p 0 -X stuff "$opt_rpc$(printf \\r)"
  screen -S farcaster -p 0 -X stuff "$farcaster_fid$(printf \\r)"

  # Получение внешнего IP и вывод ссылки на дашборд
  echo -e "${INFO} ${YELLOW}Получение внешнего IP...${NC}"
  external_ip=$(curl -s ifconfig.me)
  echo -e "${CHECK_MARK} ${GREEN}Установка завершена!${NC}"
  echo -e "${INFO} ${YELLOW}Дашборд доступен по ссылке: http://${external_ip}:3000${NC}"
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
  echo -е "${INFO} ${YELLOW}Просмотр логов...${NC}"
  screen -r farcaster
}

# Функция для вывода текущих значений RPC и FID
show_config() {
  echo -е "${INFO} ${YELLOW}Чтение конфигурационного файла...${NC}"
  if [ -f "$HOME/hubble/.env" ]; then
    source "$HOME/hubble/.env"
    echo -е "${INFO} ${YELLOW}Текущие значения:${NC}"
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
  else
    echo -е "${CROSS_MARK} ${RED}Изменение значений отменено.${NC}"
  fi
}

# Основная логика скрипта
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
  status)
    node_status
    ;;  
  *)
    echo -е "${INFO} ${YELLOW}Использование: $0 {install|update|remove|logs|show-config|change-config|status}${NC}"
    ;;
esac
