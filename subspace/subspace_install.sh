#!/bin/bash

# Цветовая палитра и переменные
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

DIR="$HOME/subspace-pulsar"
PULSAR="$DIR/pulsar"
SERVICE="$DIR/subspace-pulsar.service"
CONFIG_URL="https://github.com/BananaAlliance/guides/raw/main/subspace/config.sh"

# Скачивание файла конфигурации
wget -q -O $DIR/config.sh $CONFIG_URL
source $DIR/config.sh

# Функция для логирования
log() {
    local message="$1"
    local log_file="$DIR/install.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
}

# Функция для вывода и логирования сообщений
echo_and_log() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${NC}"
    log "${message}"
}

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo_and_log "Успешно!" $GREEN
    else
        echo_and_log "Не удалось." $RED
        exit 1
    fi
}

# Функция для извлечения и вывода адреса для наград
show_reward_address() {
    local file="$HOME/subspace_docker/docker-compose.yml"
    local address=$(grep -oP '"--reward-address", "\K[^"]+' "$file")
    local node_name=$(grep -oP '"--name", "\K[^"]+' "$file")

    if [[ ! -z $address ]]; then
        echo_and_log "Ваше название ноды: $node_name" $GREEN
    else
        echo_and_log "Название ноды не найдено, следуйте инструкциям в гайде." $RED
    fi
    
    if [[ ! -z $address ]]; then
        echo_and_log "Ваш адрес для наград: $address" $GREEN
    else
        echo_and_log "Адрес не найден, следуйте инструкциям в гайде." $RED
    fi
}

# Создание необходимых папок
create_folders() {
    echo_and_log "Создание необходимых папок..." $YELLOW
    mkdir -p $DIR
    check_success
}

# Скачивание файла
download_file() {
    echo_and_log "Скачивание файла..." $YELLOW
    wget -q -O $PULSAR $PULSAR_URL
    check_success
    sleep 1
}

# Инициализация ноды
init_node() {
    echo_and_log "Инициализация ноды..." $YELLOW
    chmod +x $PULSAR
    $PULSAR init
    check_success
    sleep 1
}

# Создание сервисного файла
create_service_file() {
    echo_and_log "Создание сервисного файла..." $YELLOW
    cat <<EOF > $SERVICE
[Unit]
Description=Subspace Pulsar Node
After=network.target

[Service]
ExecStart=$PULSAR farm
WorkingDirectory=$DIR
User=$USER
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    check_success
    sleep 1
}

# Запуск сервиса ноды
start_service() {
    echo_and_log "Запуск сервиса ноды..." $YELLOW
    sudo ln -s $SERVICE /etc/systemd/system/subspace-pulsar.service
    sudo systemctl daemon-reload
    sudo systemctl enable subspace-pulsar
    sudo systemctl start subspace-pulsar
    check_success
    sleep 1
}

# Проверка статуса сервиса
check_service_status() {
    echo_and_log "Проверка статуса сервиса..." $YELLOW
    systemctl is-active --quiet subspace-pulsar
    check_success
    sleep 1
}

# Проверка наличия уже существующих файлов перед установкой
pre_install_check() {
    if [ -d $DIR ]; then
        echo_and_log "Кажется, Subspace Pulsar уже установлен. Вы уверены, что хотите продолжить? Это может перезаписать существующие файлы." $YELLOW
        read -p "Продолжить установку? (y/n): " choice
        if [[ $choice != "y" ]]; then
            echo_and_log "Установка отменена." $RED
            sleep 1
            exit 1
        fi
    fi
}

# Удаление установленной ноды
uninstall_node() {
    echo_and_log "Проверка наличия установленной ноды..." $YELLOW
    if [ -d $DIR ]; then
        echo_and_log "Нода Subspace установлена. Вы действительно хотите удалить ее?" $YELLOW
        read -p "Удалить ноду? (y/n): " choice
        if [[ $choice == "y" ]]; then
            echo_and_log "Остановка и удаление сервиса..." $YELLOW
            sudo systemctl stop subspace-pulsar
            sudo systemctl disable subspace-pulsar
            sudo rm -f /etc/systemd/system/subspace-pulsar.service
            sudo systemctl daemon-reload

            echo_and_log "Выполнение команды pulsar wipe..." $YELLOW
            $DIR/pulsar wipe
            check_success

            echo_and_log "Удаление файлов..." $YELLOW
            sleep 1
            rm -rf $DIR
            check_success
            sleep 1
        else
            echo_and_log "Удаление отменено пользователем." $GREEN
        fi
    else
        echo_and_log "Нода Subspace не обнаружена." $GREEN
    fi
}

# Обновление ноды
update_node() {
    echo_and_log "Проверка версии..." $YELLOW
    INSTALLED_VERSION=$($PULSAR --version | awk '{print $2}')
    if [ $INSTALLED_VERSION == $CURRENT_VERSION ]; then
        echo_and_log "У вас уже установлена последняя версия." $GREEN
        exit 0
    fi
    sudo systemctl stop subspace-pulsar.service
    echo_and_log "Обновление ноды..." $YELLOW
    download_file
    chmod +x $PULSAR
    check_success
    echo_and_log "Перезапуск сервиса..." $YELLOW
    sudo systemctl restart subspace-pulsar
    check_success
}

# Запуск установки ноды
install_node() {
    pre_install_check
    create_folders
    download_file
    show_reward_address
    init_node
    create_service_file
    start_service
    check_service_status
}

# Определение действия: установка или удаление
case $1 in
    install)
        install_node
        ;;
    uninstall)
        uninstall_node
        ;;
    update)
        update_node
        ;;
    *)
        echo_and_log "Неверный аргумент. Используйте 'install' для установки или 'uninstall' для удаления." $RED
        ;;
esac
