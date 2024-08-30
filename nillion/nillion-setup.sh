#!/bin/bash

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

# Цвета для оформления
COLOR_RED="\e[31m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_BLUE="\e[34m"
COLOR_CYAN="\e[36m"
COLOR_RESET="\e[0m"

# Функция для вывода сообщений
log() {
    echo -e "${COLOR_CYAN}$1${COLOR_RESET}"
}

# Функция для обработки ошибок
handle_error() {
    echo -e "${COLOR_RED}❌ Ошибка: $1${COLOR_RESET}"
    exit 1
}

# Функция для проверки, установлен ли пакет
check_and_install_package() {
    if ! dpkg -l | grep -qw "$1"; then
        log "${COLOR_YELLOW}📦 Устанавливаем $1...${COLOR_RESET}"
        sudo apt-get install -y "$1" || handle_error "Не удалось установить $1."
    else
        log "${COLOR_GREEN}✔️  $1 уже установлен!${COLOR_RESET}"
    fi
}

# Функция подготовки сервера
prepare_server() {
    log "${COLOR_BLUE}🔄 Обновляем сервер и устанавливаем необходимые пакеты...${COLOR_RESET}"
    sudo apt-get update -y && sudo apt-get upgrade -y || handle_error "Не удалось обновить сервер."

    local packages=("curl" "software-properties-common" "ca-certificates" "apt-transport-https" "screen")
    for package in "${packages[@]}"; do
        check_and_install_package "$package"
    done
}

# Проверка, установлен ли Docker
check_docker_installed() {
    if command -v docker &> /dev/null; then
        log "${COLOR_GREEN}🐋 Docker уже установлен!${COLOR_RESET}"
    else
        install_docker
    fi
}

# Установка Docker
install_docker() {
    log "${COLOR_BLUE}🐋 Устанавливаем Docker...${COLOR_RESET}"
    wget -O- https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable"| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    check_and_install_package "docker-ce"
}

# Установка ноды Nillion
install_node() {
    log "${COLOR_BLUE}🚀 Устанавливаем ноду Nillion...${COLOR_RESET}"
    docker pull nillion/retailtoken-accuser:v1.0.0 || handle_error "Не удалось загрузить образ Docker для ноды."
    
    mkdir -p $HOME/nillion/accuser || handle_error "Не удалось создать директорию для данных ноды."
    
    docker run -v $HOME/nillion/accuser:/var/tmp nillion/retailtoken-accuser:v1.0.0 initialise || handle_error "Не удалось инициализировать ноду."
    
    log "${COLOR_GREEN}🎉 Нода инициализирована! Скопируйте account_id и public_key и зарегистрируйте их на сайте.${COLOR_RESET}"
    log "${COLOR_CYAN}📁 Файл credentials.json сохранен в директории $HOME/nillion/accuser.${COLOR_RESET}"

    log "${COLOR_YELLOW}🚰 ВАЖНО: Перед началом работы убедитесь, что вы получили токены Nillion на ваш кошелек. Перейдите на сайт крана и запросите токены: https://faucet.testnet.nillion.com/${COLOR_RESET}"

}

# Функция запуска процесса accuser
run_accuser() {
    log "${COLOR_BLUE}🕒 Запуск процесса accuser...${COLOR_RESET}"
    
    echo -e "${COLOR_YELLOW}Введите номер блока для запуска (например, 5159667):${COLOR_RESET}"
    read block_start

    screen -dmS nillion_accuser docker run -v $HOME/nillion/accuser:/var/tmp nillion/retailtoken-accuser:v1.0.0 accuse --rpc-endpoint "https://testnet-nillion-rpc.lavenderfive.com" --block-start $block_start
    log "${COLOR_GREEN}🎉 Процесс accuser запущен в screen сессии 'nillion_accuser'.${COLOR_RESET}"

    echo $(date +%s) > $HOME/nillion/accuser/timestamp
}

# Функция остановки процесса accuser
stop_accuser() {
    log "${COLOR_BLUE}🛑 Останавливаем процесс accuser...${COLOR_RESET}"
    screen -S nillion_accuser -X quit || handle_error "Не удалось остановить процесс accuser."
    log "${COLOR_GREEN}✅ Процесс accuser успешно остановлен.${COLOR_RESET}"
}

# Функция рестарта процесса accuser
restart_accuser() {
    stop_accuser
    run_accuser
}

# Подтверждение удаления ноды
confirm_removal() {
    read -p "Вы уверены, что хотите удалить ноду и все её данные? [y/N]: " confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            log "${COLOR_YELLOW}Удаление отменено.${COLOR_RESET}"
            exit 0
            ;;
    esac
}

# Удаление ноды
remove_node() {
    confirm_removal

    log "${COLOR_RED}🗑️ Удаление ноды...${COLOR_RESET}"
    docker rm -f $(docker ps -a -q --filter ancestor=nillion/retailtoken-accuser:v1.0.0) || handle_error "Не удалось удалить контейнеры ноды."
    rm -rf $HOME/nillion || handle_error "Не удалось удалить директорию с данными ноды."
    log "${COLOR_GREEN}✅ Нода успешно удалена.${COLOR_RESET}"
}

# Функция помощи
display_help() {
    echo -e "${COLOR_BLUE}🆘 Доступные команды:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}1${COLOR_RESET} - Установить ноду: подготовка сервера, установка Docker, установка и инициализация ноды."
    echo -e "${COLOR_GREEN}2${COLOR_RESET} - Запустить ноду: запуск процесса accuser."
    echo -e "${COLOR_GREEN}3${COLOR_RESET} - Остановить ноду: остановка процесса accuser."
    echo -e "${COLOR_GREEN}4${COLOR_RESET} - Рестарт ноды: остановка и повторный запуск процесса accuser."
    echo -e "${COLOR_GREEN}5${COLOR_RESET} - Удалить ноду: удаление ноды и всех связанных с ней файлов."
    echo -e "${COLOR_GREEN}6${COLOR_RESET} - Помощь: отображает это сообщение."
}

# Основная функция управления
main() {
    log "${COLOR_BLUE}Выберите действие:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}1${COLOR_RESET} - Установить ноду"
    echo -e "${COLOR_GREEN}2${COLOR_RESET} - Запустить ноду"
    echo -e "${COLOR_GREEN}3${COLOR_RESET} - Остановить ноду"
    echo -e "${COLOR_GREEN}4${COLOR_RESET} - Рестарт ноды"
    echo -e "${COLOR_GREEN}5${COLOR_RESET} - Удалить ноду"
    echo -e "${COLOR_GREEN}6${COLOR_RESET} - Помощь"

    read -p "Введите номер действия: " action
    case $action in
        1)
            prepare_server
            check_docker_installed
            install_node
            ;;
        2)
            run_accuser
            ;;
        3)
            stop_accuser
            ;;
        4)
            restart_accuser
            ;;
        5)
            remove_node
            ;;
        6)
            display_help
            ;;
        *)
            log "${COLOR_YELLOW}Некорректный ввод. Пожалуйста, выберите действие от 1 до 6.${COLOR_RESET}"
            ;;
    esac
}

# Запуск основного процесса
main "$@"