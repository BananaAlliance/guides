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
SCRIPT_VERSION="1.0.0"

# Функция для отображения заголовка
show_header() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}       Мастер установки Nexus${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
}

# Функция для отображения разделителя
show_separator() {
    echo -e "${BLUE}--------------------------------------${NC}"
}

# Проверка, установлена ли нода
is_node_installed() {
    if [ -d "$HOME/nexus/network-api" ]; then
        return 0
    else
        return 1
    fi
}

# Проверка, запущена ли нода
is_node_running() {
    if systemctl is-active --quiet nexus; then
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
    sudo journalctl -u nexus -f
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
    sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
    check_error
    echo -e "${INSTALL} ${GREEN}Установка Rust...${NC}"
    sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
    source $HOME/.cargo/env
    export PATH="$HOME/.cargo/bin:$PATH"
    rustup update
    check_error
    echo -e "${CHECKMARK} ${GREEN}Зависимости успешно установлены.${NC}"
}

# Установка ноды Nexus
install_node() {
    show_header
    echo -e "${NODE} ${GREEN}Установка ноды Nexus...${NC}"
    show_separator
    if [ -d "$HOME/nexus/network-api" ]; then
        echo -e "${INFO} ${YELLOW}Nexus уже установлен. Обновление...${NC}"
        (cd $HOME/nexus/network-api && git pull)
    else
        mkdir -p $HOME/nexus
        (cd $HOME/nexus && git clone https://github.com/nexus-xyz/network-api)
    fi
    (cd $HOME/nexus/network-api/clients/cli && cargo build --release)
    check_error
    create_service_file
    echo -e "${CHECKMARK} ${GREEN}Нода Nexus успешно установлена.${NC}"
}

# Создание сервисного файла для systemd
create_service_file() {
    show_header
    echo -e "${INSTALL} ${GREEN}Создание сервисного файла для ноды Nexus...${NC}"
    show_separator

    NEXUS_PATH="$HOME/nexus/network-api/clients/cli/target/release/prover"

    sudo bash -c "cat << EOF > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Node
After=network.target

[Service]
User=$(whoami)
Environment=PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.cargo/bin
ExecStart=$NEXUS_PATH beta.orchestrator.nexus.xyz
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable nexus
    echo -e "${SUCCESS} ${GREEN}Сервис создан и настроен.${NC}"
}

# Запуск/остановка/управление нодой
manage_node() {
    while true; do
        show_header
        echo -e "${NODE} ${YELLOW}Меню управления нодой:${NC}"
        show_separator
        echo "1. Старт ноды ${CHECKMARK}"
        echo "2. Стоп ноды ${ERROR}"
        echo "3. Рестарт ноды ${PROGRESS}"
        echo "4. Просмотр логов ${INFO}"
        echo "5. Вернуться в главное меню ↩️"
        show_separator
        read -p "Выберите опцию (1-5): " option

        case $option in
            1)
                sudo systemctl start nexus
                echo -e "${CHECKMARK} ${GREEN}Нода запущена.${NC}"
                ;;
            2)
                sudo systemctl stop nexus
                echo -e "${CHECKMARK} ${GREEN}Нода остановлена.${NC}"
                ;;
            3)
                sudo systemctl restart nexus
                echo -e "${PROGRESS} ${GREEN}Нода перезапущена.${NC}"
                ;;
            4)
                view_logs
                ;;
            5)
                return
                ;;
            *)
                echo -e "${ERROR} ${RED}Неверный выбор!${NC}"
                ;;
        esac
        read -p "Нажмите Enter, чтобы продолжить"
    done
}

# Главное меню
main_menu() {
    while true; do
        show_header
        echo -e "${SUCCESS} ${GREEN}Добро пожаловать в мастер установки Nexus!${NC}"
        show_separator

        if is_node_installed; then
            if is_node_running; then
                echo "1. Управление нодой ${NODE}"
                echo "2. Остановить ноду ${ERROR}"
                echo "3. Просмотреть логи ${INFO}"
                echo "4. Выйти ${ERROR}"
            else
                echo "1. Запустить ноду ${CHECKMARK}"
                echo "2. Удалить ноду ${ERROR}"
                echo "3. Просмотреть логи ${INFO}"
                echo "4. Выйти ${ERROR}"
            fi
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
                        manage_node
                    else
                        sudo systemctl start nexus
                        sleep 2
                        if is_node_running; then
                            echo -e "${CHECKMARK} ${GREEN}Нода Nexus успешно запущена.${NC}"
                        else
                            echo -e "${ERROR} ${RED}Не удалось запустить ноду. Проверьте логи для получения дополнительной информации.${NC}"
                        fi
                    fi
                else
                    install_dependencies
                    install_node
                fi
                ;;
            2)
                if is_node_installed; then
                    if is_node_running; then
                        sudo systemctl stop nexus
                        echo -e "${CHECKMARK} ${GREEN}Нода остановлена.${NC}"
                    else
                        sudo systemctl disable nexus
                        sudo rm -rf $HOME/nexus
                        sudo rm /etc/systemd/system/nexus.service
                        sudo systemctl daemon-reload
                        echo -e "${SUCCESS} ${GREEN}Нода Nexus успешно удалена.${NC}"
                    fi
                else
                    echo -e "${SUCCESS} ${GREEN}Спасибо за использование мастера установки Nexus!${NC}"
                    exit 0
                fi
                ;;
            3)
                view_logs
                ;;
            4)
                echo -e "${SUCCESS} ${GREEN}Спасибо за использование мастера установки Nexus!${NC}"
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
    REPO_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/nexus/nexus-wizzard.sh"

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