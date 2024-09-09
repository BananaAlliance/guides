#!/bin/bash

# Цвета для логирования
COLOR_RESET="\e[0m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_RED="\e[31m"
COLOR_BLUE="\e[34m"

LOG_DIR="./logs"
ERROR_LOG="failed_servers.log"
SERVERS_FILE="servers.conf"
mkdir -p "$LOG_DIR"
echo "" > "$ERROR_LOG"  # Очищаем файл ошибок

MAX_ATTEMPTS=3
PARALLEL_JOBS=5  # Количество параллельных установок

SCRIPT_VERSION=1.0.1

self_update() {
    # URL скрипта на GitHub
    REPO_URL="https://github.com/BananaAlliance/guides/raw/main/elixir/elixir-mass.sh"

    # Получаем удаленную версию скрипта
    REMOTE_VERSION=$(curl -s $REPO_URL | grep "SCRIPT_VERSION=" | cut -d '"' -f 2)

    if [ "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]; then
        log "${COLOR_YELLOW}⚠️ Доступна новая версия скрипта ($REMOTE_VERSION). Обновляем...${COLOR_RESET}"

        # Скачиваем новую версию во временный файл
        TEMP_SCRIPT=$(mktemp)
        wget -O "$TEMP_SCRIPT" "$REPO_URL" || handle_error "Не удалось загрузить обновление."

        # Замена текущего скрипта на новый
        mv "$TEMP_SCRIPT" "$0" || handle_error "Не удалось обновить скрипт."
        chmod +x "$0"

        log "${COLOR_GREEN}✔️ Скрипт успешно обновлен до версии $REMOTE_VERSION.${COLOR_RESET}"

        # Перезапускаем скрипт после обновления
        exec "$0" "$@"
    else
        log "${COLOR_GREEN}✔️ У вас уже установлена последняя версия скрипта (${SCRIPT_VERSION}).${COLOR_RESET}"
    fi
}

# Логирование
log() {
    echo -e "$1"
}

# Обработка ошибок с повторной попыткой
handle_error() {
    local ATTEMPT=$1
    log "${COLOR_RED}❌ $2 (попытка $ATTEMPT из $MAX_ATTEMPTS)${COLOR_RESET}"
    local DELAY=$((2**$ATTEMPT)) # Экспоненциальная задержка
    log "${COLOR_YELLOW}🔄 Повторная попытка через $DELAY секунд...${COLOR_RESET}"
    sleep $DELAY
}

self_update

# Функция проверки и установки пакета
check_and_install_package() {
    if ! dpkg -l | grep -qw "$1"; then
        log "${COLOR_YELLOW}📦 Устанавливаем $1...${COLOR_RESET}"
        sudo apt-get install -y "$1" || handle_error "Не удалось установить $1."
    else
        log "${COLOR_GREEN}✔️  $1 уже установлен!${COLOR_RESET}"
    fi
}

# Функция проверки и установки Docker
check_and_install_docker() {
    if ! command -v docker &> /dev/null; then
        log "${COLOR_YELLOW}🐳 Docker не найден. Устанавливаем Docker...${COLOR_RESET}"
        sudo install -m 0755 -d /etc/apt/keyrings || handle_error "Не удалось создать директорию /etc/apt/keyrings."
        wget -O- https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null || handle_error "Не удалось загрузить и сохранить ключ Docker GPG."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || handle_error "Не удалось добавить репозиторий Docker."
        sudo apt-get update -y || handle_error "Не удалось обновить список пакетов."
        check_and_install_package "docker-ce"
    else
        log "${COLOR_GREEN}✔️  Docker уже установлен!${COLOR_RESET}"
    fi
}

# Проверка наличия файла с серверами
if [ ! -f "$SERVERS_FILE" ]; then
    log "${COLOR_RED}❌ Файл $SERVERS_FILE не найден! Пожалуйста, создайте его и укажите список серверов.${COLOR_RESET}"
    exit 1
fi

# Функция для установки ноды на сервере
install_node_on_server() {
    local IP=$1
    local USER=$2
    local PASSWORD=$3
    local NODE_NAME=$4
    local METAMASK_ADDRESS=$5
    local PRIVATE_KEY=$6

    LOG_FILE="$LOG_DIR/$IP.log"

    log "${COLOR_BLUE}🚀 Устанавливаем ноду на сервере $IP...${COLOR_RESET}"

    # Подключаемся по SSH и выполняем команды, сохраняя вывод в лог
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$USER@$IP" <<EOF &> "$LOG_FILE"
        echo "🌐 Подключены к серверу $IP..."

        # Установка Docker и необходимых пакетов
        $(typeset -f check_and_install_package)
        $(typeset -f check_and_install_docker)

        check_and_install_docker
        check_and_install_package curl

        ENV_DIR="\$HOME/.elixir"
        ENV_FILE="\$ENV_DIR/.env"
        mkdir -p "\$ENV_DIR"

        echo "ENV=testnet-3
STRATEGY_EXECUTOR_DISPLAY_NAME=$NODE_NAME
STRATEGY_EXECUTOR_BENEFICIARY=$METAMASK_ADDRESS
SIGNER_PRIVATE_KEY=$(echo "$PRIVATE_KEY" | sed 's/^0x//')
STRATEGY_EXECUTOR_IP_ADDRESS=\$(curl -4 -s ifconfig.me)" > "\$ENV_FILE"

        docker pull elixirprotocol/validator:v3
        docker run -d --env-file "\$ENV_FILE" --name elixir --restart unless-stopped elixirprotocol/validator:v3

        echo "✔️ Нода успешно установлена на $IP!"
EOF
}

# Основной процесс установки на всех серверах
install_on_all_servers() {
    while IFS=':' read -r IP USER PASSWORD NODE_NAME METAMASK_ADDRESS PRIVATE_KEY; do
        ATTEMPTS=0
        while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
            install_node_on_server "$IP" "$USER" "$PASSWORD" "$NODE_NAME" "$METAMASK_ADDRESS" "$PRIVATE_KEY" && break
            ATTEMPTS=$((ATTEMPTS + 1))
            handle_error $ATTEMPTS "Не удалось установить ноду на сервере $IP"
        done

        if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
            log "${COLOR_RED}❌ Установка ноды на сервере $IP провалилась после $MAX_ATTEMPTS попыток.${COLOR_RESET}"
            echo "$IP:$USER:$PASSWORD:$NODE_NAME:$METAMASK_ADDRESS:$PRIVATE_KEY" >> "$ERROR_LOG"  # Записываем сервер в лог ошибок
        fi
    done < "$SERVERS_FILE"
}

# Повторная установка на серверах с ошибками
retry_failed_servers() {
    if [ ! -s "$ERROR_LOG" ]; then
        log "${COLOR_GREEN}✔️ Все серверы установлены успешно. Повторных попыток не требуется.${COLOR_RESET}"
    else
        log "${COLOR_YELLOW}🔄 Повторная попытка установки для серверов из $ERROR_LOG...${COLOR_RESET}"
        SERVERS_FILE="$ERROR_LOG"  # Используем файл ошибок как список серверов для повторной установки
        echo "" > "$ERROR_LOG"  # Очищаем лог ошибок перед повторной установкой
        install_on_all_servers
    fi
}

# Параллельный запуск установки с ограничением количества одновременных процессов
install_in_parallel() {
    while IFS=':' read -r IP USER PASSWORD NODE_NAME METAMASK_ADDRESS PRIVATE_KEY; do
        ATTEMPTS=0
        {
            while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
                install_node_on_server "$IP" "$USER" "$PASSWORD" "$NODE_NAME" "$METAMASK_ADDRESS" "$PRIVATE_KEY" && break
                ATTEMPTS=$((ATTEMPTS + 1))
                handle_error $ATTEMPTS "Не удалось установить ноду на сервере $IP"
            done

            if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
                log "${COLOR_RED}❌ Установка ноды на сервере $IP провалилась после $MAX_ATTEMPTS попыток.${COLOR_RESET}"
                echo "$IP:$USER:$PASSWORD:$NODE_NAME:$METAMASK_ADDRESS:$PRIVATE_KEY" >> "$ERROR_LOG"  # Записываем сервер в лог ошибок
            fi
        } &
        
        # Ограничение параллельных процессов
        if (( $(jobs -r | wc -l) >= PARALLEL_JOBS )); then
            wait -n
        fi
    done < "$SERVERS_FILE"
    wait  # Ожидание завершения всех фоновых процессов
}

# Основной процесс
install_in_parallel
retry_failed_servers
echo "Установка нод завершена на всех серверах!"