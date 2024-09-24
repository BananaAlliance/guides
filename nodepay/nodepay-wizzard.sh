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
PROGRESS="🔄"
INSTALL="📦"
SUCCESS="🎉"
WARNING="⚠️"
NODE="🖥️"
INFO="ℹ️"
LOGS="📜"

SCRIPT_VERSION="1.0.3"
OCEAN_NODE_DIR="$HOME/ocean-node"
DOCKER_COMPOSE_FILE="$OCEAN_NODE_DIR/docker-compose.yml"
DOCKER_CONTAINER_NAME="ocean-node"

# Функция отображения заголовка
show_header() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}       Ocean Node Setup Wizard${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
}

# Функция для отображения разделителя
show_separator() {
    echo -e "${BLUE}--------------------------------------${NC}"
}

# Функция для прогресс-бара
progress_bar() {
    echo -ne "${PROGRESS} Пожалуйста, подождите: ["
    for ((i=0; i<=25; i++)); do
        echo -ne "▓"
        sleep 0.1
    done
    echo -e "]${NC} ${SUCCESS} Готово!"
}

# Функция для проверки системных требований
check_system_requirements() {
    local required_cpu=2  # минимальное количество CPU ядер
    local required_ram=4  # минимальный объем оперативной памяти (в ГБ)
    local required_disk=20 # минимальный объем свободного места на диске (в ГБ)
    local node_name="Ocean Node"

    echo -e "${BLUE}${INFO} Проверка системных требований для ноды $node_name...${NC}"
    show_separator

    local cpu_cores=$(nproc)
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    local free_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

    # Проверка CPU
    if [ $cpu_cores -ge $required_cpu ]; then
        echo -e "${GREEN}${CHECKMARK} CPU: $cpu_cores ядер (требуется $required_cpu)${NC}"
        cpu_status="OK"
    else
        echo -e "${RED}${ERROR} CPU: $cpu_cores ядер (требуется $required_cpu)${NC}"
        cpu_status="Недостаточно"
    fi

    # Проверка RAM
    if [ $total_ram -ge $required_ram ]; then
        echo -e "${GREEN}${CHECKMARK} RAM: $total_ram ГБ (требуется $required_ram ГБ)${NC}"
        ram_status="OK"
    else
        echo -e "${RED}${ERROR} RAM: $total_ram ГБ (требуется $required_ram ГБ)${NC}"
        ram_status="Недостаточно"
    fi

    # Проверка диска
    if [ $free_disk -ge $required_disk ]; then
        echo -e "${GREEN}${CHECKMARK} Свободное место на диске: $free_disk ГБ (требуется $required_disk ГБ)${NC}"
        disk_status="OK"
    else
        echo -e "${RED}${ERROR} Свободное место на диске: $free_disk ГБ (требуется $required_disk ГБ)${NC}"
        disk_status="Недостаточно"
    fi

    show_separator

    # Статус системы
    if [[ $cpu_status == "OK" && $ram_status == "OK" && $disk_status == "OK" ]]; then
        echo -e "${GREEN}${CHECKMARK} Статус: Полностью совместимо${NC}"
        return 0
    else
        echo -e "${RED}${ERROR} Статус: Несовместимо${NC}"
        return 1
    fi
}

# Функция проверки и установки необходимых пакетов
check_installed() {
    local PACKAGE=$1
    if dpkg -l | grep -q "$PACKAGE"; then
        echo -e "${CHECKMARK} ${GREEN}$PACKAGE уже установлен.${NC}"
    else
        echo -e "${INSTALL} ${YELLOW}Устанавливаем $PACKAGE...${NC}"
        sudo apt install -y $PACKAGE
        check_error
        echo -e "${CHECKMARK} ${GREEN}$PACKAGE установлен.${NC}"
    fi
}

install_packages() {
    show_header
    echo -e "${NODE} ${GREEN}Обновление системы и установка необходимых пакетов...${NC}"
    show_separator
    sudo apt update && sudo apt upgrade -y
    check_error

    progress_bar

    check_installed "curl"
    check_installed "screen"
    check_installed "htop"
}

# Функция проверки установки Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${PROGRESS} Docker не установлен, начинаем установку..."
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
        echo -e "${CHECKMARK} Docker установлен."
    else
        echo -e "${CHECKMARK} Docker уже установлен."
    fi
}

# Функция проверки, установлен ли Ocean Node
is_node_installed() {
    if [ -d "$OCEAN_NODE_DIR" ] && [ -f "$DOCKER_COMPOSE_FILE" ];then
        return 0
    else
        return 1
    fi
}

# Функция проверки, запущен ли Ocean Node
is_node_running() {
    if docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
        return 0
    else
        return 1
    fi
}

# Функция отображения статуса Ocean Node
show_node_status() {
    if is_node_installed; then
        if is_node_running; then
            echo -e "${CHECKMARK} ${GREEN}Ocean Node установлен и запущен.${NC}"
        else
            echo -e "${WARNING} ${YELLOW}Ocean Node установлен, но не запущен.${NC}"
        fi
    else
        echo -e "${ERROR} ${RED}Ocean Node не установлен.${NC}"
    fi
}

# Функция установки Ocean Node
install_ocean_node() {
    show_header
    check_docker

    # Проверка системных требований
    if ! check_system_requirements; then
        echo -e "${ERROR} ${RED}Системные требования не соответствуют минимальным требованиям.${NC}"
        return
    fi

    install_packages

    # Шаг 1: Клонирование репозитория
    if [ ! -d "$OCEAN_NODE_DIR" ]; then
        echo -e "${PROGRESS} Клонируем репозиторий Ocean Node..."
        git clone https://github.com/oceanprotocol/ocean-node.git "$OCEAN_NODE_DIR"
        echo -e "${CHECKMARK} Репозиторий успешно склонирован."
    else
        echo -e "${INFO} Репозиторий уже существует. Пропускаем клонирование."
    fi

    # Шаг 2: Запуск скрипта генерации docker-compose.yml
    echo -e "${PROGRESS} Генерация Docker файла..."
    cd "$OCEAN_NODE_DIR"
    bash scripts/ocean-node-quickstart.sh
    echo -e "${CHECKMARK} Docker файл сгенерирован."

    # Шаг 3: Поднятие контейнера с помощью Docker Compose
    echo -e "${PROGRESS} Запуск Ocean Node через Docker Compose..."
    docker compose up -d
    echo -e "${CHECKMARK} Ocean Node запущен."

    show_node_status
}

# Функция остановки Ocean Node
stop_ocean_node() {
    if is_node_running; then
        echo -e "${PROGRESS} Остановка Ocean Node..."
        docker compose -f "$DOCKER_COMPOSE_FILE" down
        echo -e "${SUCCESS} Ocean Node остановлен."
    else
        echo -e "${WARNING} Ocean Node уже остановлен."
    fi
}

# Функция просмотра логов Ocean Node
view_logs() {
    if is_node_installed; then
        echo -e "${INFO} ${LOGS} Просмотр логов Ocean Node..."
        docker logs -f "$DOCKER_CONTAINER_NAME"
    else
        echo -e "${ERROR} Ocean Node не установлен, логи недоступны."
    fi
}

# Функция самообновления
self_update() {
    # URL скрипта на GitHub
    REPO_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/nodepay/nodepay-wizzard.sh"

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

# Главное меню
main_menu() {
    while true; do
        show_header
        if is_node_installed; then
            show_node_status
        fi

        if ! is_node_installed; then
            echo -e "${CYAN}1) Установить Ocean Node ${INSTALL}${NC}"
        else
            if is_node_running; then
                echo -e "${CYAN}2) Остановить Ocean Node ${ERROR}${NC}"
                echo -e "${CYAN}3) Просмотреть логи ${LOGS}${NC}"
            else
                echo -e "${CYAN}2) Запустить Ocean Node ${CHECKMARK}${NC}"
                echo -e "${CYAN}3) Просмотреть логи ${LOGS}${NC}"
            fi
        fi

        echo -e "${CYAN}4) Обновить скрипт ${PROGRESS}${NC}"
        echo -e "${CYAN}0) Выйти${NC}"
        show_separator
        read -p "Выберите опцию: " choice

        case $choice in
            1)
                if ! is_node_installed; then
                    install_ocean_node
                else
                    echo -e "${WARNING} Ocean Node уже установлен.${NC}"
                fi
                ;;
            2)
                if is_node_running; then
                    stop_ocean_node
                else
                    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
                    echo -e "${CHECKMARK} Ocean Node запущен.${NC}"
                fi
                ;;
            3)
                view_logs
                ;;
            4)
                self_update
                ;;
            0)
                echo -e "${SUCCESS} Завершение работы.${NC}"
                exit 0
                ;;
            *)
                echo -e "${ERROR} Неверный выбор, попробуйте снова.${NC}"
                ;;
        esac
        read -p "Нажмите Enter для продолжения..."
    done
}

# Запуск главного меню
main_menu