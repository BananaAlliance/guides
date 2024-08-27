#!/bin/bash

# Colors for styling
COLOR_RED="\e[31m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_BLUE="\e[34m"
COLOR_CYAN="\e[36m"
COLOR_RESET="\e[0m"

# Logging function with emoji support
log() {
    echo -e "${COLOR_CYAN}$1${COLOR_RESET}"
}

# Function to display help
display_help() {
    echo -e "${COLOR_BLUE}🆘 Доступные команды:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}install${COLOR_RESET}   - Установка ноды: подготовка сервера, скачивание, создание кошелька, запуск ноды."
    echo -e "${COLOR_GREEN}start${COLOR_RESET}     - Запуск ноды: запускает сервис ноды."
    echo -e "${COLOR_GREEN}stop${COLOR_RESET}      - Остановка ноды: останавливает сервис ноды."
    echo -e "${COLOR_GREEN}restart${COLOR_RESET}   - Перезапуск ноды: перезапускает сервис ноды."
    echo -e "${COLOR_GREEN}remove${COLOR_RESET}    - Удаление ноды: удаляет сервис ноды и связанные файлы."
    echo -e "${COLOR_GREEN}logs${COLOR_RESET}      - Просмотр логов: показывает логи работы ноды в реальном времени."
    echo -e "${COLOR_GREEN}help${COLOR_RESET}      - Помощь: отображает это сообщение."
}

# Error handling with emoji support
handle_error() {
    echo -e "${COLOR_RED}❌ Ошибка: $1${COLOR_RESET}"
    exit 1
}

# Function to check if a file exists
check_file_exists() {
    if [ -f "$1" ]; then
        log "${COLOR_YELLOW}⚠️  Файл $1 уже существует. Пропуск скачивания.${COLOR_RESET}"
        return 1
    fi
    return 0
}

# Function to check if a directory exists
check_directory_exists() {
    if [ -d "$1" ]; then
        log "${COLOR_GREEN}📁 Директория $1 уже существует.${COLOR_RESET}"
    else
        log "${COLOR_YELLOW}📂 Создание директории $1...${COLOR_RESET}"
        mkdir -p "$1" || handle_error "Не удалось создать директорию $1."
    fi
}

# Function to check and install a package if not already installed
check_and_install_package() {
    if ! dpkg -l | grep -qw "$1"; then
        log "${COLOR_YELLOW}📦 Установка $1...${COLOR_RESET}"
        sudo apt-get install -y "$1" || handle_error "Не удалось установить $1."
    else
        log "${COLOR_GREEN}✔️  $1 уже установлен!${COLOR_RESET}"
    fi
}

# Prepare the server by updating and installing necessary packages
prepare_server() {
    log "${COLOR_BLUE}🔄 Обновление сервера и установка необходимых пакетов...${COLOR_RESET}"
    sudo apt-get update -y && sudo apt-get upgrade -y || handle_error "Не удалось обновить сервер."

    local packages=("make" "build-essential" "pkg-config" "libssl-dev" "unzip" "tar" "lz4" "gcc" "git" "jq")
    for package in "${packages[@]}"; do
        check_and_install_package "$package"
    done
}

# Download and extract the Fractal Node repository
download_and_extract() {
    local url="https://github.com/fractal-bitcoin/fractald-release/releases/download/v0.1.7/fractald-0.1.7-x86_64-linux-gnu.tar.gz"
    local filename="fractald-0.1.7-x86_64-linux-gnu.tar.gz"
    local dirname="fractald-0.1.7-x86_64-linux-gnu"

    check_file_exists "$filename"
    if [ $? -eq 0 ]; then
        log "${COLOR_BLUE}⬇️  Скачивание Fractal Node...${COLOR_RESET}"
        wget -q "$url" -O "$filename" || handle_error "Не удалось скачать $filename."
    fi

    log "${COLOR_BLUE}🗜️  Распаковка $filename...${COLOR_RESET}"
    tar -zxvf "$filename" || handle_error "Не удалось распаковать $filename."

    check_directory_exists "$dirname/data"
    cp "$dirname/bitcoin.conf" "$dirname/data" || handle_error "Не удалось скопировать bitcoin.conf в $dirname/data."
}

# Check if the wallet already exists
check_wallet_exists() {
    if [ -f "/root/.bitcoin/wallets/wallet/wallet.dat" ]; then
        log "${COLOR_GREEN}💰 Кошелек уже существует. Пропуск создания кошелька.${COLOR_RESET}"
        return 1
    fi
    return 0
}

# Create a new wallet
create_wallet() {
    log "${COLOR_BLUE}🔍 Проверка существования кошелька...${COLOR_RESET}"
    check_wallet_exists
    if [ $? -eq 1 ]; then
        log "${COLOR_GREEN}✅ Кошелек уже существует. Нет необходимости создавать новый.${COLOR_RESET}"
        return
    fi

    log "${COLOR_BLUE}💼 Создание нового кошелька...${COLOR_RESET}"

    cd fractald-0.1.7-x86_64-linux-gnu/bin || handle_error "Не удалось перейти в директорию bin."
    ./bitcoin-wallet -wallet=wallet -legacy create || handle_error "Не удалось создать кошелек."

    log "${COLOR_BLUE}🔑 Экспорт приватного ключа кошелька...${COLOR_RESET}"
    ./bitcoin-wallet -wallet=/root/.bitcoin/wallets/wallet/wallet.dat -dumpfile=/root/.bitcoin/wallets/wallet/MyPK.dat dump || handle_error "Не удалось экспортировать приватный ключ кошелька."

    PRIVATE_KEY=$(awk -F 'checksum,' '/checksum/ {print "Приватный ключ кошелька:" $2}' /root/.bitcoin/wallets/wallet/MyPK.dat)
    log "${COLOR_RED}$PRIVATE_KEY${COLOR_RESET}"
    log "${COLOR_YELLOW}⚠️  Не забудьте записать ваш приватный ключ!${COLOR_RESET}"
}

# Create a systemd service file for Fractal Node
create_service_file() {
    log "${COLOR_BLUE}🛠️  Создание системного сервиса для Fractal Node...${COLOR_RESET}"

    if [ -f "/etc/systemd/system/fractald.service" ]; then
        log "${COLOR_YELLOW}⚠️  Файл сервиса уже существует. Пропуск создания.${COLOR_RESET}"
    else
        sudo tee /etc/systemd/system/fractald.service > /dev/null << EOF
[Unit]
Description=Fractal Node
After=network-online.target
[Service]
User=$USER
ExecStart=/root/fractald-0.1.7-x86_64-linux-gnu/bin/bitcoind -datadir=/root/fractald-0.1.7-x86_64-linux-gnu/data/ -maxtipage=504576000
Restart=always
RestartSec=5
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload || handle_error "Не удалось выполнить daemon-reload."
        sudo systemctl enable fractald || handle_error "Не удалось включить сервис fractald."
    fi
}

# Start the Fractal Node service
start_node() {
    log "${COLOR_BLUE}🚀 Запуск Fractal Node...${COLOR_RESET}"
    sudo systemctl start fractald || handle_error "Не удалось запустить сервис fractald."
    log "${COLOR_GREEN}🎉 Fractal Node запущен и работает!${COLOR_RESET}"
    log "${COLOR_CYAN}📝 Чтобы проверить логи ноды, выполните команду: ${COLOR_BLUE}sudo journalctl -u fractald -f --no-hostname -o cat${COLOR_RESET}"
}

# Stop the Fractal Node service
stop_node() {
    log "${COLOR_BLUE}🛑 Остановка Fractal Node...${COLOR_RESET}"
    sudo systemctl stop fractald || handle_error "Не удалось остановить сервис fractald."
    log "${COLOR_GREEN}✔️ Fractal Node остановлен.${COLOR_RESET}"
}

# Restart the Fractal Node service
restart_node() {
    log "${COLOR_BLUE}🔄 Перезапуск Fractal Node...${COLOR_RESET}"
    sudo systemctl restart fractald || handle_error "Не удалось перезапустить сервис fractald."
    log "${COLOR_GREEN}🔁 Fractal Node успешно перезапущен!${COLOR_RESET}"
}

# Remove the Fractal Node service and files
remove_node() {
    log "${COLOR_RED}⚠️  Удаление Fractal Node...${COLOR_RESET}"
    sudo systemctl stop fractald || handle_error "Не удалось остановить сервис fractald."
    sudo systemctl disable fractald || handle_error "Не удалось отключить сервис fractald."
    sudo rm /etc/systemd/system/fractald.service || handle_error "Не удалось удалить файл сервиса."
    sudo systemctl daemon-reload || handle_error "Не удалось выполнить daemon-reload."
    sudo rm -rf /root/fractald-0.1.7-x86_64-linux-gnu || handle_error "Не удалось удалить файлы Fractal Node."
    log "${COLOR_GREEN}✔️ Fractal Node успешно удален.${COLOR_RESET}"
}

# View logs of the Fractal Node service
view_logs() {
    log "${COLOR_BLUE}📜 Просмотр логов Fractal Node...${COLOR_RESET}"
    sudo journalctl -u fractald -f --no-hostname -o cat
}

# Main function to control the flow of the script based on arguments
main() {
    case $1 in
        install)
            prepare_server
            download_and_extract
            create_service_file
            create_wallet
            start_node
            ;;
        start)
            start_node
            ;;
        stop)
            stop_node
            ;;
        restart)
            restart_node
            ;;
        remove)
            remove_node
            ;;
        logs)
            view_logs
            ;;
        help)
            display_help
            ;;
        *)
            log "${COLOR_YELLOW}Использование: $0 {install|start|stop|restart|remove|logs|help}${COLOR_RESET}"
            ;;
    esac
}

# Start the main process
main "$@"
