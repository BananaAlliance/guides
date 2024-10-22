#!/bin/bash

# Цвета и эмодзи для оформления
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
NODE="🖥️"
INFO="ℹ️"
ADDRESS="💰"

SCRIPT_VERSION="1.1.2"
# Версия ноды Hemi
LATEST_NODE_VERSION="0.4.5"
NODE_DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v${LATEST_NODE_VERSION}/heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz"

# Файл конфигурации серверов (формат: IP:USERNAME:PASSWORD)
SERVERS_FILE="servers.conf"

# Массив для хранения сгенерированных адресов
ALL_ADDRESSES=()

# Функция логирования действий
log() {
    echo -e "$1"
}

# Функция для отображения заголовка
show_header() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}       Мастер массовой установки Hemi${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
}

# Функция для проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} ${RED}Ошибка выполнения команды. Остановка установки.${NC}"
        exit 1
    fi
}

# Функция для установки необходимых пакетов
install_packages() {
    echo -e "${NODE} ${GREEN}Установка необходимых пакетов на сервере...${NC}"
    sudo apt update && sudo apt install -y curl tar wget
    check_error
    echo -e "${CHECKMARK} ${GREEN}Пакеты успешно установлены.${NC}"
}

# Функция для установки Hemi
install_hemi() {
    echo -e "${NODE} ${GREEN}Скачивание и установка Hemi v${LATEST_NODE_VERSION}...${NC}"
    
    wget $NODE_DOWNLOAD_URL -O heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error
    
    tar -xvf heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error
    
    rm heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error

    mv heminetwork_v${LATEST_NODE_VERSION}_linux_amd64 $HOME/heminetwork
    check_error

    echo "${LATEST_NODE_VERSION}" > $HOME/heminetwork/version.txt
    check_error

    echo -e "${CHECKMARK} ${GREEN}Hemi v${LATEST_NODE_VERSION} успешно установлена.${NC}"
}

# Функция для генерации и вывода биткоин-адресов
generate_and_show_addresses() {
    echo -e "${INFO} ${CYAN}Генерация Bitcoin адресов...${NC}"
    cd $HOME/heminetwork
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
    check_error

    # Получаем сгенерированный адрес
    local ADDRESS=$(cat ~/popm-address.json | grep "pubkey_hash" | awk -F '"' '{print $4}')
    echo -e "${ADDRESS} ${GREEN}Сгенерированный Bitcoin-адрес: $ADDRESS${NC}"

    # Возвращаем адрес для дальнейшей обработки
    echo "$ADDRESS"
}

# Функция создания системного сервиса
create_service_file() {
    echo -e "${INSTALL} ${GREEN}Создание системного сервиса для Hemi...${NC}"

    PRIVATE_KEY=$(cat $HOME/popm-address.json | grep "private_key" | awk -F '"' '{print $4}')
    check_error

    sudo bash -c "cat << EOF > /etc/systemd/system/hemi.service
[Unit]
Description=Hemi Node
After=network.target

[Service]
User=$(whoami)
Environment=POPM_BTC_PRIVKEY=$PRIVATE_KEY
Environment=POPM_STATIC_FEE=50
Environment=POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
ExecStart=$HOME/heminetwork/popmd
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF"
    check_error

    sudo systemctl daemon-reload
    sudo systemctl enable hemi
    sudo systemctl start hemi
    check_error

    echo -e "${SUCCESS} ${GREEN}Сервис Hemi успешно создан и запущен.${NC}"
}

# Функция удаления ноды
remove_hemi() {
    echo -e "${ERROR} ${YELLOW}Удаление Hemi и связанных файлов...${NC}"
    
    sudo systemctl stop hemi
    sudo systemctl disable hemi
    sudo rm /etc/systemd/system/hemi.service
    sudo systemctl daemon-reload
    rm -rf $HOME/heminetwork
    check_error

    echo -e "${SUCCESS} ${GREEN}Hemi успешно удалена.${NC}"
}

# Функция обновления ноды
update_hemi() {
    echo -e "${PROGRESS} ${YELLOW}Обновление Hemi до версии v${LATEST_NODE_VERSION}...${NC}"
    
    wget $NODE_DOWNLOAD_URL -O heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error
    
    tar -xvf heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error

    rm heminetwork_v${LATEST_NODE_VERSION}_linux_amd64.tar.gz
    check_error

    rm -rf $HOME/heminetwork
    mv heminetwork_v${LATEST_NODE_VERSION}_linux_amd64 $HOME/heminetwork
    check_error

    echo "${LATEST_NODE_VERSION}" > $HOME/heminetwork/version.txt
    check_error

    sudo systemctl restart hemi
    check_error

    echo -e "${SUCCESS} ${GREEN}Hemi успешно обновлена до версии ${LATEST_NODE_VERSION}.${NC}"
}

# Функция для отображения прогресс-бара
show_progress() {
    local duration=$1
    local steps=$2
    local step_duration=$(echo "scale=2; $duration / $steps" | bc)
    local progress=0
    while [ $progress -lt $steps ]
    do
        echo -ne "\rПрогресс: [${GREEN}"
        for ((i=0; i<$progress; i++)); do echo -ne "#"; done
        for ((i=$progress; i<$steps; i++)); do echo -ne "."; done
        echo -ne "${NC}] $((progress * 100 / steps))%"
        sleep $step_duration
        ((progress++))
    done
    echo -ne "\rПрогресс: [${GREEN}";for ((i=0; i<$steps; i++)); do echo -ne "#"; done; echo -e "${NC}] 100%"
}

# Функция для массовой установки на все сервера из файла
mass_action() {
    action=$1
    total_servers=$(grep -v '^#' "$SERVERS_FILE" | grep -v '^$' | wc -l)
    current_server=0

    while IFS=':' read -r IP USER PASSWORD; do
        # Пропускаем пустые строки и комментарии
        [[ -z "$IP" || "$IP" == \#* ]] && continue

        ((current_server++))
        log "${NODE} ${BLUE}Начинаем операцию на сервере: $IP (${current_server}/${total_servers})${NC}"
        
        if [ "$action" == "install" ]; then
            echo "Шаг 1/4: Установка необходимых пакетов"
            show_progress 2 10
            echo "Шаг 2/4: Установка Hemi"
            show_progress 3 10
            echo "Шаг 3/4: Генерация Bitcoin-адреса"
            show_progress 1 10
            echo "Шаг 4/4: Создание и запуск сервиса"
            show_progress 2 10
        elif [ "$action" == "remove" ]; then
            echo "Удаление Hemi"
            show_progress 5 10
        elif [ "$action" == "update" ]; then
            echo "Обновление Hemi"
            show_progress 5 10
        fi

        ADDR=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$USER@$IP" bash <<EOF
            LATEST_NODE_VERSION="$LATEST_NODE_VERSION"
            NODE_DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v\${LATEST_NODE_VERSION}/heminetwork_v\${LATEST_NODE_VERSION}_linux_amd64.tar.gz"
            
            $(declare -f install_packages install_hemi generate_and_show_addresses create_service_file remove_hemi update_hemi check_error)
            
            if [ "$action" == "install" ]; then
                install_packages >/dev/null 2>&1
                install_hemi >/dev/null 2>&1
                ADDRESS=\$(generate_and_show_addresses | grep "Сгенерированный Bitcoin-адрес:" | awk '{print \$NF}')
                create_service_file >/dev/null 2>&1
                echo "\$ADDRESS"
            elif [ "$action" == "remove" ]; then
                remove_hemi >/dev/null 2>&1
            elif [ "$action" == "update" ]; then
                update_hemi >/dev/null 2>&1
            fi
EOF
)
        # Добавляем адрес в массив, если операция установки
        if [ "$action" == "install" ]; then
            ALL_ADDRESSES+=("$ADDR")
        fi

        log "${CHECKMARK} ${GREEN}Операция завершена на сервере: $IP${NC}"
        echo ""
    done < "$SERVERS_FILE"
}

# Функция для вывода всех сгенерированных адресов
show_all_addresses() {
    echo -e "${ADDRESS} ${CYAN}Все сгенерированные Bitcoin-адреса:${NC}"
    for addr in "${ALL_ADDRESSES[@]}"; do
        echo "$addr"
    done
}

# Обработка аргументов командной строки
if [ "$1" == "install" ]; then
    show_header
    mass_action "install"
    show_all_addresses
elif [ "$1" == "remove" ]; then
    show_header
    mass_action "remove"
elif [ "$1" == "update" ]; then
    show_header
    mass_action "update"
else
    echo -e "${ERROR} ${RED}Неверный аргумент. Используйте: install, remove или update.${NC}"
    exit 1
fi




