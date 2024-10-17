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
WALLET="👛"

SCRIPT_VERSION="1.1.0"
# Установка актуальной версии ноды
LATEST_NODE_VERSION="0.4.5"
NODE_DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v${LATEST_NODE_VERSION}/heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz"


# Функция для отображения заголовка
show_header() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}       Мастер установки Hemi${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
}

# Функция для отображения статуса ноды
show_node_status() {
    if is_node_installed; then
        if is_node_running; then
            echo -e "${CHECKMARK} ${GREEN}Статус ноды: Установлена и запущена${NC}"
        else
            echo -e "${WARNING} ${YELLOW}Статус ноды: Установлена, но не запущена${NC}"
        fi
    else
        echo -e "${ERROR} ${RED}Статус ноды: Не установлена${NC}"
    fi
}


# Функция для отображения информации о системе
show_system_info() {
    show_header
    echo -e "${INFO} ${CYAN}Информация о системе:${NC}"
    show_separator
    echo -e "${YELLOW}Операционная система:${NC} $(uname -s)"
    echo -e "${YELLOW}Версия ядра:${NC} $(uname -r)"
    echo -e "${YELLOW}Процессор:${NC} $(lscpu | grep 'Model name' | cut -f 2 -d ":")"
    echo -e "${YELLOW}Оперативная память:${NC} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${YELLOW}Свободное место на диске:${NC} $(df -h / | awk '/\// {print $4}')"
    show_separator
    read -p "Нажмите Enter, чтобы вернуться в главное меню"
}

# Функция для отображения разделителя
show_separator() {
    echo -e "${BLUE}--------------------------------------${NC}"
}

# Проверка, установлена ли нода
is_node_installed() {
    if command -v $HOME/heminetwork_v0.4.3_linux_amd64/popmd &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Проверка, запущена ли нода
is_node_running() {
    if systemctl is-active --quiet hemi; then
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
    sudo journalctl -u hemi -f
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

# Проверка на ошибки
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} ${RED}Ошибка выполнения. Пожалуйста, проверьте логи и повторите попытку.${NC}"
        exit 1
    fi
}

# Проверка установленных пакетов
check_installed() {
    PACKAGE=$1
    if dpkg -l | grep -q "$PACKAGE"; then
        echo -e "${CHECKMARK} ${GREEN}$PACKAGE уже установлен.${NC}"
    else
        echo -e "${INSTALL} ${YELLOW}Устанавливаем $PACKAGE...${NC}"
        sudo apt install -y $PACKAGE
        check_error
        echo -e "${CHECKMARK} ${GREEN}$PACKAGE установлен.${NC}"
    fi
}

# Функция установки необходимых пакетов
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

# Функция для проверки системных требований
check_system_requirements() {
    local required_cpu=$1
    local required_ram=$2  # в ГБ
    local required_disk=$3 # в ГБ
    local node_name=$4

    echo -e "${BLUE}${INFO} Проверка системных требований для ноды $node_name...${NC}"
    echo -e "${BLUE}---------------------------------------------------${NC}"

    # Получаем информацию о системе
    local cpu_cores=$(nproc)
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    local free_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

    # Проверяем CPU
    if [ $cpu_cores -ge $required_cpu ]; then
        echo -e "${GREEN}${CHECKMARK} CPU: $cpu_cores ядер (требуется $required_cpu)${NC}"
        local cpu_status="OK"
    else
        echo -e "${RED}${ERROR} CPU: $cpu_cores ядер (требуется $required_cpu)${NC}"
        local cpu_status="Недостаточно"
    fi

    # Проверяем RAM
    if [ $total_ram -ge $required_ram ]; then
        echo -e "${GREEN}${CHECKMARK} RAM: $total_ram ГБ (требуется $required_ram ГБ)${NC}"
        local ram_status="OK"
    else
        echo -e "${RED}${ERROR} RAM: $total_ram ГБ (требуется $required_ram ГБ)${NC}"
        local ram_status="Недостаточно"
    fi

    # Проверяем диск
    if [ $free_disk -ge $required_disk ]; then
        echo -e "${GREEN}${CHECKMARK} Свободное место на диске: $free_disk ГБ (требуется $required_disk ГБ)${NC}"
        local disk_status="OK"
    else
        echo -e "${RED}${ERROR} Свободное место на диске: $free_disk ГБ (требуется $required_disk ГБ)${NC}"
        local disk_status="Недостаточно"
    fi

    echo -e "${BLUE}---------------------------------------------------${NC}"

    # Определяем общий статус совместимости
    if [[ $cpu_status == "OK" && $ram_status == "OK" && $disk_status == "OK" ]]; then
        echo -e "${GREEN}${CHECKMARK} Статус: Полностью совместимо${NC}"
        return 0
    elif [[ $cpu_status == "OK" && $ram_status == "OK" && $disk_status == "Недостаточно" ]]; then
        echo -e "${YELLOW}${WARNING} Статус: Совместимо, но рекомендуется увеличить объем диска${NC}"
        return 1
    elif [[ $cpu_status == "OK" && $ram_status == "Недостаточно" ]]; then
        echo -e "${YELLOW}${WARNING} Статус: Совместимо с ограничениями (недостаточно RAM)${NC}"
        return 2
    else
        echo -e "${RED}${ERROR} Статус: Несовместимо${NC}"
        return 3
    fi
}

install_hemi() {
    show_header
    echo -e "${NODE} ${GREEN}Проверка системных требований для Hemi...${NC}"
    show_separator

    check_system_requirements 2 4 40 "Hemi"
    compatibility_status=$?

    case $compatibility_status in
        0)
            echo -e "${GREEN}Система полностью совместима. Продолжаем установку.${NC}"
            ;;
        1|2)
            echo -e "${YELLOW}Система не полностью соответствует требованиям. Продолжить установку? (y/n)${NC}"
            read -r answer
            if [[ ! $answer =~ ^[Yy]$ ]]; then
                echo -e "${RED}Установка отменена.${NC}"
                return
            fi
            ;;
        3)
            echo -e "${RED}Система несовместима. Установка невозможна.${NC}"
            return
            ;;
    esac

    echo -e "${NODE} ${GREEN}Устанавливаем Hemi...${NC}"
    show_separator

    wget $NODE_DOWNLOAD_URL -O heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error

    tar -xvf heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz && rm heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error

    # Перемещаем распакованную папку в каталог установки
    mv heminetwork_v${LATEST_NODE_VERSION}_linux_amd64 $HOME/heminetwork
    check_error

    # Записываем версию ноды в файл version.txt
    echo "${LATEST_NODE_VERSION}" > $HOME/heminetwork/version.txt

    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
    check_error

    echo -e "${INFO} ${CYAN}Адрес вашего tBTC кошелька:${NC}"
    cat $HOME/popm-address.json | grep "pubkey_hash" | awk -F '"' '{print $4}'
    show_separator

    echo -e "${INFO} ${YELLOW}Отправляйтесь в дискорд и запросите тестовые токены в канале #faucet${NC}"
    echo -e "${INFO} ${YELLOW}Впишите /tbtc-faucet адрес_tbtc и дождитесь подтвержденной транзакции.${NC}"
    show_separator

    read -p "Нажмите Enter, чтобы продолжить после получения тестовых токенов..."

    PRIVATE_KEY=$(cat $HOME/popm-address.json | grep "private_key" | awk -F '"' '{print $4}')
    echo "export POPM_BTC_PRIVKEY=$PRIVATE_KEY" >> ~/.bashrc
    echo "export POPM_STATIC_FEE=50" >> ~/.bashrc
    echo "export POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> ~/.bashrc
    source ~/.bashrc

    echo -e "${SUCCESS} ${GREEN}Hemi успешно установлен!${NC}"
    show_separator
}



create_service_file() {
    show_header
    echo -e "${INSTALL} ${GREEN}Создание сервисного файла для автоматического управления нодой...${NC}"
    show_separator

    HEMI_PATH=$(pwd)/popmd

    PRIVATE_KEY=$(cat $HOME/popm-address.json | grep "private_key" | awk -F '"' '{print $4}')


    sudo bash -c "cat << EOF > /etc/systemd/system/hemi.service
[Unit]
Description=Hemi Node
After=network.target

[Service]
User=$(whoami)
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=POPM_BTC_PRIVKEY=$PRIVATE_KEY
Environment=POPM_STATIC_FEE=50
Environment=POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
ExecStart=$HEMI_PATH
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable hemi
    echo -e "${SUCCESS} ${GREEN}Сервис создан и настроен.${NC}"
    echo -e "${INFO} ${YELLOW}Примечание: Сервис не будет запущен автоматически.${NC}"
    echo -e "${INFO} ${YELLOW}Для настройки и запуска ноды выполните команду:${NC}"
    echo -e "${CYAN}sudo systemctl start hemi${NC}"
}

update_node() {
    show_header
    echo -e "${PROGRESS} ${YELLOW}Обновление ноды Hemi...${NC}"
    show_separator

    if is_node_running; then
        echo -e "${INFO} ${BLUE}Останавливаем ноду для обновления...${NC}"
        sudo systemctl stop hemi
    fi

    echo -e "${INSTALL} ${YELLOW}Обновляем пакет heminetwork до версии ${LATEST_NODE_VERSION}...${NC}"
    wget $NODE_DOWNLOAD_URL -O heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error

    tar -xvf heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz && rm heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error

    # Перемещаем обновленную ноду в каталог установки
    rm -rf $HOME/heminetwork
    mv heminetwork_v${LATEST_NODE_VERSION}_linux_amd64 $HOME/heminetwork
    check_error

    # Записываем версию ноды в файл version.txt
    echo "${LATEST_NODE_VERSION}" > $HOME/heminetwork/version.txt

    echo -e "${PROGRESS} ${YELLOW}Перезапускаем ноду...${NC}"
    sudo systemctl start hemi
    check_error

    echo -e "${SUCCESS} ${GREEN}Нода Hemi успешно обновлена до версии ${LATEST_NODE_VERSION} и перезапущена!${NC}"
}

check_node_version() {
    local installed_version
    if [[ -f $HOME/heminetwork/version.txt ]]; then
        installed_version=$(cat $HOME/heminetwork/version.txt)
    else
        installed_version="Не установлена"
    fi

    echo -e "${INFO} ${CYAN}Установленная версия ноды: ${installed_version}${NC}"
    echo -e "${INFO} ${CYAN}Актуальная версия ноды: ${LATEST_NODE_VERSION}${NC}"

    if [[ "$installed_version" != "$LATEST_NODE_VERSION" ]]; then
        echo -e "${WARNING} ${YELLOW}Доступна новая версия ноды (${LATEST_NODE_VERSION}). Рекомендуется обновить ноду.${NC}"
    else
        echo -e "${CHECKMARK} ${GREEN}Нода обновлена до последней версии.${NC}"
    fi
}



self_update() {
    # URL скрипта на GitHub
    REPO_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/hemi/hemi-wizzard.sh"

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

        # Перезапускаем скрипт после обновления
        exec "$0" "$@"
    else
        echo -e "${CHECKMARK} ${GREEN}У вас уже установлена последняя версия скрипта (${SCRIPT_VERSION}).${NC}"
    fi
}

# Обновленное главное меню
main_menu() {
    while true; do
        show_header
        echo -e "${SUCCESS} ${GREEN}Добро пожаловать в мастер установки Hemi!${NC}"
        echo -e "${SUCCESS} ${GREEN}Версия скрипта: ${SCRIPT_VERSION}"
        show_separator
        show_node_status
        check_node_version
        show_separator

        if is_node_installed; then
            if is_node_running; then
                echo "1. Управление нодой ${NODE}"
                echo "2. Просмотреть логи ${INFO}"
                echo "3. Остановить ноду ${ERROR}"
                echo "4. Информация о системе ${INFO}"
                echo "5. Обновить ноду ${PROGRESS}"
                echo "6. Обновить скрипт ${PROGRESS}"
            else
                echo "1. Запустить ноду ${CHECKMARK}"
                echo "2. Просмотреть логи ${INFO}"
                echo "3. Удалить ноду ${ERROR}"
                echo "4. Информация о системе ${INFO}"
                echo "5. Обновить ноду ${PROGRESS}"
                echo "6. Обновить скрипт ${PROGRESS}"
            fi
        else
            echo "1. Установить ноду ${INSTALL}"
            echo "2. Информация о системе ${INFO}"
            echo "3. Обновить скрипт ${PROGRESS}"
        fi

        echo "0. Выйти ${ERROR}"
        show_separator
        read -p "Выберите опцию: " choice

        case $choice in
            1)
                if is_node_installed; then
                    if is_node_running; then
                        manage_node
                    else
                        echo -e "${PROGRESS} ${YELLOW}Запускаем ноду Hemi...${NC}"
                        sudo systemctl start hemi
                        sleep 2
                        if is_node_running; then
                            echo -e "${CHECKMARK} ${GREEN}Нода Hemi успешно запущена.${NC}"
                        else
                            echo -e "${ERROR} ${RED}Не удалось запустить ноду. Проверьте логи для получения дополнительной информации.${NC}"
                        fi
                    fi
                else
                    install_packages
                    install_hemi
                    create_service_file
                fi
                ;;
            2)
                if is_node_installed; then
                    view_logs
                else
                    show_system_info
                fi
                ;;
            3)
                if is_node_installed; then
                    if is_node_running; then
                        sudo systemctl stop hemi
                        echo -e "${CHECKMARK} ${GREEN}Нода остановлена.${NC}"
                    else
                        remove_node
                    fi
                else
                    self_update
                fi
                ;;
            4)
                show_system_info
                ;;
            5)
                if is_node_installed; then
                    update_node
                else
                    echo -e "${ERROR} ${RED}Нода не установлена. Сначала установите ноду.${NC}"
                fi
                ;;
            6)
                if is_node_installed; then
                    self_update
                else
                    echo -e "${ERROR} ${RED}Неверный выбор!${NC}"
                fi
                ;;
            0)
                show_header
                echo -e "${SUCCESS} ${GREEN}Спасибо за использование мастера установки Hemi!${NC}"
                exit 0
                ;;
            *)
                echo -e "${ERROR} ${RED}Неверный выбор!${NC}"
                ;;
        esac
        read -p "Нажмите Enter, чтобы продолжить"
    done
}

# Запуск обновления скрипта перед запуском главного меню
self_update

# Запуск главного меню
main_menu
