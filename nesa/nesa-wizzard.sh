#!/bin/bash

# Цвета и эмодзи
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

CHECKMARK="✅"
ERROR="❌"
PROGRESS="⏳"
INSTALL="📦"
SUCCESS="🎉"
WARNING="⚠️"
NODE="🖥️"
INFO="ℹ️"
SCRIPT_VERSION="1.1.0"

# Функция для отображения заголовка
show_header() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}       Мастер установки Nesa${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
}

# Функция для отображения разделителя
show_separator() {
    echo -e "${BLUE}--------------------------------------${NC}"
}

# Проверка, установлена ли нода
is_node_installed() {
    if docker ps -a --format '{{.Names}}' | grep -q "^orchestrator$"; then
        return 0
    else
        return 1
    fi
}

# Проверка, запущена ли нода
is_node_running() {
    if docker ps --format '{{.Names}}' | grep -q "^orchestrator$" && docker ps --format '{{.Names}}' | grep -q "^ipfs_node$"; then
        return 0
    else
        return 1
    fi
}

# Просмотр логов ноды
view_logs() {
    show_header
    echo -e "${NODE} ${GREEN}Просмотр логов ноды...${NC}"
    show_separator
    docker logs -f orchestrator
}

# Проверка на ошибки
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} ${RED}Ошибка выполнения. Пожалуйста, проверьте логи и повторите попытку.${NC}"
        exit 1
    fi
}

# Установка зависимостей
install_dependencies() {
    show_header
    echo -e "${INSTALL} ${GREEN}Установка зависимостей...${NC}"
    show_separator
    sudo apt update && sudo apt upgrade -y
    sudo apt install jq curl -y
    check_error
    echo -e "${INSTALL} ${GREEN}Установка Docker...${NC}"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y
    check_error
    echo -e "${INSTALL} ${GREEN}Установка Docker Compose...${NC}"
    VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    check_error
    echo -e "${CHECKMARK} ${GREEN}Зависимости успешно установлены.${NC}"
}

# Установка ноды Nesa
install_node() {
    show_header
    echo -e "${NODE} ${GREEN}Установка ноды Nesa...${NC}"
    show_separator
    
    # Открытие порта
    echo -e "${INFO} ${YELLOW}Открытие порта 31333...${NC}"
    sudo ufw allow 31333
    echo -e "${CHECKMARK} ${GREEN}Порт 31333 открыт.${NC}"

    echo -e "${INFO} ${YELLOW}Сейчас будет запущена установка. Следуйте инструкциям.${NC}"
    read -p "Нажмите Enter, чтобы продолжить..."
    bash <(curl -s https://raw.githubusercontent.com/nesaorg/bootstrap/master/bootstrap.sh)
    check_error
    echo -e "${CHECKMARK} ${GREEN}Нода Nesa успешно установлена.${NC}"
}

# Удаление ноды
remove_node() {
    show_header
    echo -e "${NODE} ${RED}Удаление ноды Nesa...${NC}"
    show_separator
    sudo docker stop orchestrator
    sudo docker stop ipfs_node
    sudo docker rm orchestrator
    sudo docker rm ipfs_node
    sudo docker images
    sudo docker rmi ghcr.io/nesaorg/orchestrator:devnet-latest
    sudo docker rmi ipfs/kubo:latest
    sudo docker image prune -a
    echo -e "${CHECKMARK} ${GREEN}Нода Nesa успешно удалена.${NC}"
}

# Перезапуск ноды
restart_node() {
    show_header
    echo -e "${NODE} ${YELLOW}Перезапуск ноды Nesa...${NC}"
    show_separator
    docker restart orchestrator mongodb docker-watchtower-1 ipfs_node
    echo -e "${CHECKMARK} ${GREEN}Нода Nesa успешно перезапущена.${NC}"
}

# Остановка ноды
stop_node() {
    show_header
    echo -e "${NODE} ${YELLOW}Остановка ноды Nesa...${NC}"
    show_separator
    docker stop orchestrator mongodb docker-watchtower-1 ipfs_node
    echo -e "${CHECKMARK} ${GREEN}Нода Nesa успешно остановлена.${NC}"
}

# Функция для получения статуса ноды
get_node_status() {
    if is_node_installed; then
        if is_node_running; then
            echo -e "${CHECKMARK} ${GREEN}Нода установлена и работает${NC}"
        else
            echo -e "${WARNING} ${YELLOW}Нода установлена, но не запущена${NC}"
        fi
    else
        echo -e "${INFO} ${BLUE}Нода не установлена${NC}"
    fi
}

# Обновленное главное меню
main_menu() {
    while true; do
        show_header
        echo -e "${SUCCESS} ${GREEN}Добро пожаловать в мастер установки Nesa!${NC}"
        echo -e "${INFO} Версия скрипта: ${SCRIPT_VERSION}"
        show_separator
        get_node_status
        show_separator

        if is_node_installed; then
            if is_node_running; then
                echo "1. Остановить ноду ${ERROR}"
                echo "2. Перезапустить ноду ${PROGRESS}"
            else
                echo "1. Запустить ноду ${CHECKMARK}"
                echo "2. Удалить ноду ${ERROR}"
            fi
            echo "3. Просмотреть логи ${INFO}"
            echo "4. Обновить ноду ${PROGRESS}"
            echo "5. Выйти ${ERROR}"
        else
            echo "1. Установить ноду ${INSTALL}"
            echo "2. Выйти ${ERROR}"
        fi
        show_separator
        read -p "Выберите опцию: " choice

        case $choice in
            1)
                if is_node_installed; then
                    if is_node_running; then
                        stop_node
                    else
                        restart_node
                    fi
                else
                    install_dependencies
                    install_node
                fi
                ;;
            2)
                if is_node_installed; then
                    if is_node_running; then
                        restart_node
                    else
                        remove_node
                    fi
                else
                    echo -e "${SUCCESS} ${GREEN}Спасибо за использование мастера установки Nesa!${NC}"
                    exit 0
                fi
                ;;
            3)
                if is_node_installed; then
                    view_logs
                else
                    echo -e "${ERROR} ${RED}Нода не установлена!${NC}"
                fi
                ;;
            4)
                if is_node_installed; then
                    echo -e "${PROGRESS} ${GREEN}Обновление ноды Nesa...${NC}"
                    stop_node
                    remove_node
                    install_node
                    echo -e "${CHECKMARK} ${GREEN}Нода Nesa успешно обновлена и перезапущена.${NC}"
                else
                    echo -e "${ERROR} ${RED}Нода не установлена!${NC}"
                fi
                ;;
            5)
                echo -e "${SUCCESS} ${GREEN}Спасибо за использование мастера установки Nesa!${NC}"
                exit 0
                ;;
            *)
                echo -e "${ERROR} ${RED}Неверный выбор!${NC}"
                ;;
        esac
        read -p "Нажмите Enter, чтобы продолжить"
    done
}

# Функция самообновления
self_update() {
    # URL скрипта на GitHub
    REPO_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/nesa/nesa-wizzard.sh"

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

        # Перезапуск скрипта после обновления
        exec "$0" "$@"
    else
        echo -e "${CHECKMARK} ${GREEN}У вас уже установлена последняя версия скрипта (${SCRIPT_VERSION}).${NC}"
    fi
}

# Запуск самообновления перед запуском главного меню
self_update

# Запуск главного меню
main_menu
