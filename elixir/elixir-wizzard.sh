#!/bin/bash

# Цвета для логирования
COLOR_RESET="\e[0m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_RED="\e[31m"
COLOR_BLUE="\e[34m"

SCRIPT_VERSION="1.0.1"



# Логирование
log() {
    echo -e "$1"
}

# Обработка ошибок
handle_error() {
    log "${COLOR_RED}❌ $1${COLOR_RESET}"
    exit 1
}

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

# Функция для обновления ноды
update_node() {
    ENV_DIR="$HOME/.elixir"
    ENV_FILE="$ENV_DIR/.env"

    # Проверяем, существует ли контейнер ноды
    if ! docker ps -a --format '{{.Names}}' | grep -qw "elixir"; then
        log "${COLOR_RED}❌ Нода не установлена. Пожалуйста, сначала выполните установку ноды.${COLOR_RESET}"
        exit 1
    fi

    # Проверяем наличие файла .env
    if [ ! -f "$ENV_FILE" ]; then
        log "${COLOR_YELLOW}⚠️ Файл .env не найден. Создаем новый .env файл...${COLOR_RESET}"
        prompt_user_input
        create_env_file
    fi

    log "${COLOR_BLUE}🛑 Остановка текущей ноды...${COLOR_RESET}"
    docker stop elixir || handle_error "Не удалось остановить ноду Elixir."

    log "${COLOR_RED}🗑 Удаление старого контейнера...${COLOR_RESET}"
    docker rm elixir || handle_error "Не удалось удалить контейнер Elixir."

    log "${COLOR_BLUE}📥 Загрузка новой версии Docker-образа...${COLOR_RESET}"
    docker pull elixirprotocol/validator:v3 || handle_error "Не удалось загрузить новый Docker-образ."

    log "${COLOR_BLUE}🚀 Запуск новой версии ноды...${COLOR_RESET}"
    docker run -d \
        --env-file "$ENV_FILE" \
        --name elixir \
        --restart unless-stopped \
        elixirprotocol/validator:v3 || handle_error "Не удалось запустить новую версию ноды Elixir."

    log "${COLOR_GREEN}✔️ Нода успешно обновлена и перезапущена!${COLOR_RESET}"
}

# Функция для запроса данных у пользователя
prompt_user_input() {
    read -p $'\e[34mВведите имя ноды: \e[0m' NODE_NAME
    read -p $'\e[34mВведите адрес Metamask: \e[0m' METAMASK_ADDRESS
    read -p $'\e[34mВведите приватный ключ: \e[0m' PRIVATE_KEY
    # Удаляем 0x если он есть
    PRIVATE_KEY=$(echo "$PRIVATE_KEY" | sed 's/^0x//')
}

# Функция для получения внешнего IP-адреса
get_external_ip() {
    log "${COLOR_BLUE}🌐 Получение внешнего IP-адреса...${COLOR_RESET}"
    EXTERNAL_IP=$(curl -4 -s ifconfig.me)
    if [ -z "$EXTERNAL_IP" ]; then
        handle_error "Не удалось получить внешний IP-адрес."
    fi
    log "${COLOR_GREEN}✔️  Внешний IP-адрес: $EXTERNAL_IP${COLOR_RESET}"
}

# Функция для создания .env файла
create_env_file() {
    ENV_DIR="$HOME/.elixir"
    ENV_FILE="$ENV_DIR/.env"

    if [ ! -d "$ENV_DIR" ]; then
        log "${COLOR_BLUE}📂 Создание директории $ENV_DIR...${COLOR_RESET}"
        mkdir -p "$ENV_DIR" || handle_error "Не удалось создать директорию $ENV_DIR."
    fi

    log "${COLOR_BLUE}📝 Создание файла .env в $ENV_FILE...${COLOR_RESET}"
    cat <<EOF > "$ENV_FILE"
ENV=testnet-3

STRATEGY_EXECUTOR_DISPLAY_NAME=$NODE_NAME
STRATEGY_EXECUTOR_BENEFICIARY=$METAMASK_ADDRESS
SIGNER_PRIVATE_KEY=$PRIVATE_KEY
STRATEGY_EXECUTOR_IP_ADDRESS=$EXTERNAL_IP
EOF

    if [ -f "$ENV_FILE" ]; then
        log "${COLOR_GREEN}✔️  Файл .env успешно создан!${COLOR_RESET}"
    else
        handle_error "Не удалось создать файл .env."
    fi
}

# Функция для запуска ноды
run_elixir_node() {
    log "${COLOR_BLUE}🔄 Загрузка Docker-образа elixirprotocol/validator:3.1.0...${COLOR_RESET}"
    docker pull elixirprotocol/validator:v3 || handle_error "Не удалось загрузить Docker-образ."

    log "${COLOR_BLUE}🚀 Запуск ноды Elixir...${COLOR_RESET}"
    docker run -d \
        --env-file "$ENV_FILE" \
        --name elixir \
        --restart unless-stopped \
        elixirprotocol/validator:v3 || handle_error "Не удалось запустить ноду Elixir."

    log "${COLOR_GREEN}✔️  Нода Elixir успешно запущена!${COLOR_RESET}"
}

# Функция для удаления ноды
remove_elixir_node() {
    log "${COLOR_RED}🛑 Удаление ноды Elixir...${COLOR_RESET}"
    docker stop elixir || handle_error "Не удалось остановить контейнер Elixir."
    docker rm elixir || handle_error "Не удалось удалить контейнер Elixir."
    log "${COLOR_GREEN}✔️  Нода Elixir успешно удалена!${COLOR_RESET}"
}

# Функция для управления нодой
manage_node_menu() {
    log "${COLOR_BLUE}📋 Меню управления нодой Elixir:${COLOR_RESET}"

    if [ "$(docker ps --filter "name=elixir" --filter "status=running" --format '{{.Names}}')" ]; then
        log "  1) Остановить ноду"
    else
        log "  1) Запустить ноду"
    fi

    log "  2) Перезапустить ноду"
    log "  3) Выйти"
    log "  4) Обновить ноду"

    read -p $'\e[34mВыберите действие: \e[0m' ACTION

    case "$ACTION" in
        1)
            if [ "$(docker ps --filter "name=elixir" --filter "status=running" --format '{{.Names}}')" ]; then
                stop_node
            else
                start_node
            fi
            ;;
        2)
            restart_node
            ;;
        3)
            log "${COLOR_GREEN}Выход из меню управления.${COLOR_RESET}"
            ;;
        4)
            update_node
            ;;
        *)
            log "${COLOR_RED}Неверный выбор. Попробуйте снова.${COLOR_RESET}"
            manage_node_menu
            ;;
    esac
}

# Функция для остановки ноды
start_node() {
    if [ "$(docker ps --filter "name=elixir" --format '{{.Names}}')" ]; then
        log "${COLOR_YELLOW}⚠️ Нода уже запущена.${COLOR_RESET}"
    else
        log "${COLOR_BLUE}🚀 Запуск ноды Elixir...${COLOR_RESET}"
        docker run -d \
            --env-file "$ENV_FILE" \
            --name elixir \
            --restart unless-stopped \
            elixirprotocol/validator:v3 || handle_error "Не удалось запустить ноду Elixir."
        log "${COLOR_GREEN}✔️ Нода Elixir успешно запущена!${COLOR_RESET}"
    fi
}

# Функция для остановки ноды
stop_node() {
    if [ "$(docker ps --filter "name=elixir" --filter "status=running" --format '{{.Names}}')" ]; then
        log "${COLOR_BLUE}🛑 Остановка ноды Elixir...${COLOR_RESET}"
        docker stop elixir || handle_error "Не удалось остановить ноду Elixir."
        log "${COLOR_GREEN}✔️ Нода Elixir успешно остановлена!${COLOR_RESET}"
    else
        log "${COLOR_YELLOW}⚠️ Нода уже остановлена или не активна.${COLOR_RESET}"
    fi
}

# Функция для рестарта ноды
restart_node() {
    log "${COLOR_BLUE}🔄 Перезапуск ноды Elixir...${COLOR_RESET}"
    docker restart elixir || handle_error "Не удалось перезапустить ноду Elixir."
    log "${COLOR_GREEN}✔️ Нода Elixir успешно перезапущена!${COLOR_RESET}"
}

# Инструкция по проверке логов
display_log_instructions() {
    log "${COLOR_BLUE}📜 Чтобы проверить логи ноды, используйте следующую команду:${COLOR_RESET}"
    log "${COLOR_YELLOW}docker logs -f elixir${COLOR_RESET}"
}

# Функция для просмотра конфигурационного файла
view_config_file() {
    if [ -f "$HOME/.elixir/.env" ]; then
        log "${COLOR_BLUE}📝 Содержимое файла конфигурации:${COLOR_RESET}"
        cat "$HOME/.elixir/.env"
    else
        handle_error "Файл конфигурации не найден."
    fi
}

# Функция для отображения помощи
display_help() {
    log "${COLOR_BLUE}Использование:${COLOR_RESET}"
    log "  $0 install       - Установка ноды Elixir"
    log "  $0 remove        - Удаление ноды Elixir"
    log "  $0 logs          - Просмотр логов ноды"
    log "  $0 view-config   - Просмотр файла конфигурации"
        log "  $0 manage        - Управление нодой (старт, стоп, рестарт)"
    log "  $0 help          - Отображение этой справки"
}

# Основной процесс установки
install_node() {
    log "${COLOR_BLUE}╔═════════════════════════════════════════════╗${COLOR_RESET}"
    log "${COLOR_BLUE}║       🚀 Установка ноды Elixir 3 фаза       ║${COLOR_RESET}"
    log "${COLOR_BLUE}╚═════════════════════════════════════════════╝${COLOR_RESET}\n"

    prompt_user_input
    get_external_ip
    create_env_file
    check_and_install_docker
    run_elixir_node

    log "${COLOR_GREEN}🎉 Установка завершена! Ваша нода Elixir работает.${COLOR_RESET}"
    display_log_instructions
}

# Основной скрипт
case "$1" in
    install)
        install_node
        ;;
    remove)
        remove_elixir_node
        ;;
    logs)
        display_log_instructions
        ;;
    view-config)
        view_config_file
        ;;
    manage)
        manage_node_menu
        ;;
    help)
        display_help
        ;;
    *)
        log "${COLOR_RED}Неизвестный аргумент: $1${COLOR_RESET}"
        display_help
        exit 1
        ;;
esac
