#!/bin/bash

# Цвета для оформления
COLOR_RESET="\e[0m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_RED="\e[31m"
COLOR_BLUE="\e[34m"
COLOR_CYAN="\e[36m"

# Эмодзи
EMOJI_ROCKET="🚀"
EMOJI_CHECK="✅"
EMOJI_ERROR="❌"
EMOJI_UPDATE="🔄"
EMOJI_SERVER="🖥️"
EMOJI_WALLET="👛"

# Файлы и директории
LOG_DIR="./logs"
ERROR_LOG="failed_servers.log"
SERVERS_FILE="servers.conf"
mkdir -p "$LOG_DIR"
echo "" > "$ERROR_LOG"

# Настройки
MAX_ATTEMPTS=3
PARALLEL_JOBS=5
SCRIPT_VERSION="1.0.0"

# Функция логирования
log() {
    echo -e "$1"
}

# Обработка ошибок
handle_error() {
    local ATTEMPT=$1
    log "${COLOR_RED}${EMOJI_ERROR} $2 (попытка $ATTEMPT из $MAX_ATTEMPTS)${COLOR_RESET}"
    local DELAY=$((2**$ATTEMPT))
    log "${COLOR_YELLOW}${EMOJI_UPDATE} Повторная попытка через $DELAY секунд...${COLOR_RESET}"
    sleep $DELAY
}

# Функция установки ноды на сервере
install_node_on_server() {
    local IP=$1
    local USER=$2
    local PASSWORD=$3
    local WALLET=$4

    LOG_FILE="$LOG_DIR/$IP.log"

    log "${COLOR_BLUE}${EMOJI_ROCKET} Устанавливаем ноду Rivalz на сервере $IP...${COLOR_RESET}"

    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$USER@$IP" <<EOF &> "$LOG_FILE"
        echo "${EMOJI_SERVER} Подключены к серверу $IP..."

        # Установка Node.js
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs

        # Установка Rivalz
        npm i -g rivalz-node-cli

        # Создание конфигурационного файла
        mkdir -p \$HOME/.rivalz
        echo "$WALLET" > \$HOME/.rivalz/wallet.txt

        # Создание сервисного файла
        sudo tee /etc/systemd/system/rivalz.service > /dev/null <<EOT
[Unit]
Description=Rivalz Node
After=network.target

[Service]
User=$USER
ExecStart=$(which rivalz) run
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOT

        # Запуск сервиса
        sudo systemctl daemon-reload
        sudo systemctl enable rivalz
        sudo systemctl start rivalz

        echo "${EMOJI_CHECK} Нода Rivalz успешно установлена на $IP!"
EOF
}

# Функция обновления ноды на сервере
update_node_on_server() {
    local IP=$1
    local USER=$2
    local PASSWORD=$3

    LOG_FILE="$LOG_DIR/$IP-update.log"

    log "${COLOR_BLUE}${EMOJI_UPDATE} Обновляем ноду Rivalz на сервере $IP...${COLOR_RESET}"

    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$USER@$IP" <<EOF &> "$LOG_FILE"
        echo "${EMOJI_SERVER} Подключены к серверу $IP..."

        rivalz update-version
        sudo systemctl restart rivalz

        echo "${EMOJI_CHECK} Нода Rivalz успешно обновлена на $IP!"
EOF
}

# Функция параллельной установки
install_in_parallel() {
    while IFS=':' read -r IP USER PASSWORD WALLET; do
        ATTEMPTS=0
        {
            while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
                install_node_on_server "$IP" "$USER" "$PASSWORD" "$WALLET" && break
                ATTEMPTS=$((ATTEMPTS + 1))
                handle_error $ATTEMPTS "Не удалось установить ноду на сервере $IP"
            done

            if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
                log "${COLOR_RED}${EMOJI_ERROR} Установка ноды на сервере $IP провалилась после $MAX_ATTEMPTS попыток.${COLOR_RESET}"
                echo "$IP:$USER:$PASSWORD:$WALLET" >> "$ERROR_LOG"
            fi
        } &
        
        if (( $(jobs -r | wc -l) >= PARALLEL_JOBS )); then
            wait -n
        fi
    done < "$SERVERS_FILE"
    wait
}

# Функция параллельного обновления
update_in_parallel() {
    while IFS=':' read -r IP USER PASSWORD WALLET; do
        ATTEMPTS=0
        {
            while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
                update_node_on_server "$IP" "$USER" "$PASSWORD" && break
                ATTEMPTS=$((ATTEMPTS + 1))
                handle_error $ATTEMPTS "Не удалось обновить ноду на сервере $IP"
            done

            if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
                log "${COLOR_RED}${EMOJI_ERROR} Обновление ноды на сервере $IP провалилось после $MAX_ATTEMPTS попыток.${COLOR_RESET}"
                echo "$IP:$USER:$PASSWORD:$WALLET" >> "$ERROR_LOG"
            fi
        } &
        
        if (( $(jobs -r | wc -l) >= PARALLEL_JOBS )); then
            wait -n
        fi
    done < "$SERVERS_FILE"
    wait
}

# Функция отображения меню
show_menu() {
    clear
    echo -e "${COLOR_CYAN}======================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN}     Мастер управления нодами Rivalz${COLOR_RESET}"
    echo -e "${COLOR_CYAN}======================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}1. ${EMOJI_ROCKET} Установить ноды на все сервера${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${EMOJI_UPDATE} Обновить ноды на всех серверах${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}3. ${EMOJI_ERROR} Выйти${COLOR_RESET}"
    echo -e "${COLOR_CYAN}======================================${COLOR_RESET}"
    echo -ne "Выберите действие (1-3): "
}

# Основной цикл программы
while true; do
    show_menu
    read -r choice

    case $choice in
        1)
            log "${COLOR_GREEN}${EMOJI_ROCKET} Начало установки нод Rivalz на всех серверах...${COLOR_RESET}"
            install_in_parallel
            log "${COLOR_GREEN}${EMOJI_CHECK} Установка нод Rivalz завершена на всех серверах!${COLOR_RESET}"
            ;;
        2)
            log "${COLOR_GREEN}${EMOJI_UPDATE} Начало обновления нод Rivalz на всех серверах...${COLOR_RESET}"
            update_in_parallel
            log "${COLOR_GREEN}${EMOJI_CHECK} Обновление нод Rivalz завершено на всех серверах!${COLOR_RESET}"
            ;;
        3)
            log "${COLOR_YELLOW}${EMOJI_CHECK} Выход из программы. До свидания!${COLOR_RESET}"
            exit 0
            ;;
        *)
            log "${COLOR_RED}${EMOJI_ERROR} Неверный выбор. Пожалуйста, выберите 1, 2 или 3.${COLOR_RESET}"
            ;;
    esac

    echo
    read -p "Нажмите Enter, чтобы продолжить..."
done
