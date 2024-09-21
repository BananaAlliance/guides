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

SCRIPT_VERSION="1.0.2"

# Функция для отображения заголовка
show_header() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}       Мастер установки Rivalz${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
}

# Функция для отображения разделителя
show_separator() {
    echo -e "${BLUE}--------------------------------------${NC}"
}

# Проверка, установлена ли нода
is_node_installed() {
    if command -v rivalz &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Проверка, запущена ли нода
is_node_running() {
    if systemctl is-active --quiet rivalz; then
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
    sudo journalctl -u rivalz -f
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

# Функция установки Rivalz
install_rivalz() {
    show_header
    echo -e "${NODE} ${GREEN}Проверка системных требований для Rivalz...${NC}"
    show_separator

    check_system_requirements 4 4 50 "Rivalz"
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

    echo -e "${NODE} ${GREEN}Устанавливаем Rivalz...${NC}"
    show_separator

    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    check_error

    check_installed "nodejs"
    npm i -g rivalz-node-cli
    check_error
    echo -e "${SUCCESS} ${GREEN}Rivalz успешно установлен!${NC}"

    show_separator
    echo -e "${INFO} ${YELLOW}Важно: Нода не запущена автоматически.${NC}"
    echo -e "${INFO} ${YELLOW}Для настройки и запуска ноды выполните следующую команду:${NC}"
    echo -e "${CYAN}rivalz run${NC}"
    echo -e "${INFO} ${YELLOW}Эта команда запросит необходимые данные, включая EVM адрес кошелька.${NC}"
    show_separator
}

create_service_file() {
    show_header
    echo -e "${INSTALL} ${GREEN}Создание сервисного файла для автоматического управления нодой...${NC}"
    show_separator

    RIVALZ_PATH=$(which rivalz)

    sudo bash -c "cat << EOF > /etc/systemd/system/rivalz.service
[Unit]
Description=Rivalz Node
After=network.target

[Service]
User=$(whoami)
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=$RIVALZ_PATH run
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable rivalz
    echo -e "${SUCCESS} ${GREEN}Сервис создан и настроен.${NC}"
    echo -e "${INFO} ${YELLOW}Примечание: Сервис не будет запущен автоматически.${NC}"
    echo -e "${INFO} ${YELLOW}Для настройки и запуска ноды выполните команду:${NC}"
    echo -e "${CYAN}rivalz run${NC}"
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

# Функция удаления ноды
remove_node() {
    echo -e "${WARNING} ${YELLOW}Удаление ноды Rivalz...${NC}"
    
    # Остановка и отключение сервиса
    sudo systemctl stop rivalz 2>/dev/null
    sudo systemctl disable rivalz 2>/dev/null
    
    # Удаление сервисного файла
    sudo rm /etc/systemd/system/rivalz.service 2>/dev/null
    
    # Удаление пакета из npm
    sudo npm uninstall -g rivalz-node-cli
    
    # Очистка npm кэша
    npm cache clean --force
    
    echo -e "${SUCCESS} ${GREEN}Нода Rivalz успешно удалена.${NC}"
}

# Меню управления нодой
manage_node() {
    while true; do
        show_header
        echo -e "${NODE} ${YELLOW}Меню управления нодой:${NC}"
        show_separator
        echo "1. Старт ноды ${CHECKMARK}"
        echo "2. Стоп ноды ${ERROR}"
        echo "3. Рестарт ноды ${PROGRESS}"
        echo "4. Просмотр логов ${INFO}"
        echo "5. Удаление ноды ${ERROR}"
        echo "6. Вернуться в главное меню ↩️"
        show_separator
        read -p "Выберите опцию (1-6): " option

        case $option in
            1)
                sudo systemctl start rivalz
                echo -e "${CHECKMARK} ${GREEN}Нода запущена.${NC}"
                ;;
            2)
                sudo systemctl stop rivalz
                echo -e "${CHECKMARK} ${GREEN}Нода остановлена.${NC}"
                ;;
            3)
                sudo systemctl restart rivalz
                echo -e "${PROGRESS} ${GREEN}Нода перезапущена.${NC}"
                ;;
            4)
                view_logs
                ;;
            5)
                remove_node
                ;;
            6)
                return
                ;;
            *)
                echo -e "${ERROR} ${RED}Неверный выбор!${NC}"
                ;;
        esac
        read -p "Нажмите Enter, чтобы продолжить"
    done
}

# Функция обновления ноды
update_node() {
    show_header
    echo -e "${PROGRESS} ${YELLOW}Обновление ноды Rivalz...${NC}"
    show_separator

    if is_node_running; then
        echo -e "${INFO} ${BLUE}Останавливаем ноду для обновления...${NC}"
        sudo systemctl stop rivalz
    fi

    echo -e "${INSTALL} ${YELLOW}Обновляем пакет rivalz-node-cli...${NC}"
    npm update -g rivalz-node-cli
    check_error

    echo -e "${PROGRESS} ${YELLOW}Перезапускаем ноду...${NC}"
    sudo systemctl start rivalz
    check_error

    echo -e "${SUCCESS} ${GREEN}Нода Rivalz успешно обновлена и перезапущена!${NC}"
}

self_update() {
    # URL скрипта на GitHub
    REPO_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/rivalz/rivalz-wizzard.sh"

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
        echo -e "${SUCCESS} ${GREEN}Добро пожаловать в мастер установки Rivalz!${NC}"
        show_separator
        show_node_status
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
                        echo -e "${PROGRESS} ${YELLOW}Запускаем ноду Rivalz...${NC}"
                        sudo systemctl start rivalz
                        sleep 2
                        if is_node_running; then
                            echo -e "${CHECKMARK} ${GREEN}Нода Rivalz успешно запущена.${NC}"
                        else
                            echo -e "${ERROR} ${RED}Не удалось запустить ноду. Проверьте логи для получения дополнительной информации.${NC}"
                        fi
                    fi
                else
                    install_packages
                    install_rivalz
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
                        sudo systemctl stop rivalz
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
                echo -e "${SUCCESS} ${GREEN}Спасибо за использование мастера установки Rivalz!${NC}"
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