#!/bin/bash

# Цветовая палитра и переменные
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE="\033[0;34m"
NC='\033[0m' # No Color

DIR="$HOME/subspace-pulsar"
PULSAR="$DIR/pulsar"
SERVICE="$DIR/subspace-pulsar.service"
CONFIG_URL="https://github.com/BananaAlliance/guides/raw/main/subspace/config.sh"

# Установим интервал обновления в 2 секунды
interval=7

# Предыдущий текущий блок (для расчета скорости)
previous_block=0

usage() {
    echo -e "${BLUE}Использование: $0 [install|update [-w [all|farmer|node]]|uninstall|show_info|change_plot]${NC}"
    echo -e "    ${GREEN}install${NC}      Установка ноды."
    echo -e "    ${GREEN}update${NC}       Запуск обновления ноды (-w аргумент для wipe - all|farmer|node)"
    echo -e "    ${RED}uninstall${NC}    Удаление ноды"
    echo -e "    ${YELLOW}show_info${NC}    Показать информацию о установленной ноде"
    echo -e "    ${YELLOW}change_plot${NC}  Изменить размер плота"
    echo -e "    ${YELLOW}logs${NC}         Открыть логи"
    echo -e "    ${YELLOW}check_sync${NC}   Проверить статус синхронизации"
    echo -e "    ${YELLOW}help${NC}         Открыть эту справку"
    exit 1
}

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
    # Скачивание файла конфигурации
    wget -q -O $DIR/config.sh $CONFIG_URL
    source $DIR/config.sh
    check_success
}

# Скачивание файла
download_file() {
    echo_and_log "Скачивание файла..." $YELLOW
    wget -q -O $PULSAR $PULSAR_URL
    sleep 1
    echo_and_log "Актуальная версия: $CURRENT_VERSION" $GREEN
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

check_sync() {
    while true; do
        clear

        latest_log_file=$(ls -t $HOME/.local/share/pulsar/logs | head -n 1)
        last_line=$(tail -n 1 $HOME/.local/share/pulsar/logs/$latest_log_file)

        if [[ $last_line == *"Syncing"* ]]; then
            current_block=$(echo $last_line | grep -o -E 'best: #([0-9]+)' | cut -d'#' -f2)
            target_block=$(echo $last_line | grep -o -E 'target=#([0-9]+)' | cut -d'#' -f2)
            difference=$((target_block - current_block))

            speed=$((current_block - previous_block))
            if [ $speed -ne 0 ]; then
                time_left_seconds=$(($difference / $speed * $interval))
                time_left_hours=$(($time_left_seconds / 3600))
                time_left_minutes=$(($time_left_seconds % 3600 / 60))
                echo "Оставшееся время: примерно $time_left_hours часов $time_left_minutes минут"
            else
                echo "Синхронизация не продвигается"
            fi

            progress=$((100 * $current_block / $target_block))
            bar_length=50
            progress_bar_length=$(($progress * $bar_length / 100))
            progress_bar=$(printf "%-${progress_bar_length}s" "=")
            spaces=$(printf "%-$(($bar_length - $progress_bar_length))s" " ")
            echo -e "Прогресс: [${progress_bar// /█}${spaces}] $progress%"

            echo "Текущий блок: $current_block"
            echo "Финальный блок: $target_block"
            echo "Оставшиеся блоки для синхронизации: $difference"

            previous_block=$current_block
        else
            # Мониторим плоттинг
            plotting_info=$(cat $HOME/.local/share/pulsar/logs/$latest_log_file | grep "plotted" | tail -n 1)
            plotting_percentage=$(echo $plotting_info | grep -o -E 'Sector plotted successfully \(([0-9.]+)%\)')
            if [[ ! -z "$plotting_percentage" ]]; then
                echo "Процесс плоттинга: $plotting_percentage"
            else
                echo "Не удалось определить состояние синхронизации. Возможно, синхронизация уже завершилась. Ждем обновления..."
            fi
        fi

        sleep $interval
    done
}


# Обновление ноды
update_node() {
    wget -q -O $DIR/config.sh $CONFIG_URL
    source $DIR/config.sh
    echo_and_log "Проверка версии..." $YELLOW
    INSTALLED_VERSION=$($PULSAR --version | awk '{print $2}')
    echo_and_log "Текущая версия: $INSTALLED_VERSION" $GREEN
    echo_and_log "Версия на сервере: $CURRENT_VERSION" $GREEN
    
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


logs() {
    latest_log_file=$(ls -t $HOME/.local/share/pulsar/logs | head -n 1)

    # Выводим оповещение
    echo -e "${YELLOW}Сейчас откроются логи, вы можете их закрыть комбинацией CTRL+C. Нажмите ENTER или любую клавишу, чтобы продолжить.${NC}"

    # Ожидаем нажатия пользователем клавиши
    read -n 1 -s

    tail -f $HOME/.local/share/pulsar/logs/$latest_log_file
}

print_node_info() {
    # Извлекаем значения из settings.toml
    node_name=$(grep "name = " $HOME/.config/pulsar/settings.toml | cut -d'"' -f2)
    farm_size=$(grep "farm_size = " $HOME/.config/pulsar/settings.toml | cut -d'"' -f2)
    reward_address=$(grep "reward_address = " $HOME/.config/pulsar/settings.toml | cut -d'"' -f2)

    # Извлекаем информацию из вывода команды
    farmer_status=$($HOME/subspace-pulsar/pulsar info | grep -q "A farmer instance is active!" && echo "Нода фермера активна" || echo "Нода фермера не активна")
    pledged_size=$($HOME/subspace-pulsar/pulsar info | grep "You have pledged to the network:" | awk '{print $7}')
    farmed_blocks=$($HOME/subspace-pulsar/pulsar info | grep "Farmed" | awk '{print $2}')
    voted_blocks=$($HOME/subspace-pulsar/pulsar info | grep "Voted" | awk '{print $3}')
    earned_coins=$(echo "scale=1; $($HOME/subspace-pulsar/pulsar info | grep "SSC(s) earned!" | awk '{print $1}') / 1000000000000000000" | bc | sed 's/^\./0./')
    plotting_status=$($HOME/subspace-pulsar/pulsar info | grep -q "Initial plotting is finished!" && echo "Плоттинг завершен" || echo "Плоттинг не завершен")

    # Выводим значения в красивом формате
    echo "======================================="
    echo "   Название узла: $node_name"
    echo "   Размер плота: ${pledged_size}GB"
    echo "   Нафармлено блоков: $farmed_blocks"
    echo "   Проголосовано блоков: $voted_blocks"
    echo "   Заработано монет: $earned_coins"
    echo "   Статус узла: $farmer_status"
    echo "   Статус плоттинга: $plotting_status"
    echo "   Публичный ключ $reward_address"
    echo "======================================="
}


update_farm_size() {
    sudo systemctl stop subspace-pulsar.service
    current_size=$($HOME/subspace-pulsar/pulsar info | grep "You have pledged to the network:" | awk '{print $7}')
    echo "Текущий размер плота: $current_size"
    #sudo rm $HOME/.local/share/pulsar/farms/plot.bin
    echo_and_log "Очистка данных фармера..." $YELLOW
    echo -e "y\nn\nn\nn" | $PULSAR wipe
    while true; do
        # Запрос на ввод размера плота
        read -p "Введите размер плота в GB (только цифры): " user_input

        # Проверка на то, что введенная строка содержит только цифры
        if [[ $user_input =~ ^[0-9]+$ ]] && [ "$user_input" -gt 0 ]; then
            # Замена размера плота в файле settings.toml
            sed -i "s/farm_size = \".* GB\"/farm_size = \"$user_input.0 GB\"/g" $HOME/.config/pulsar/settings.toml
            
            echo "Размер плота был обновлен на $user_input.0 GB"
            break
        else
            echo "Ошибка: введите правильный размер плота!"
        fi
    done
    sudo systemctl restart subspace-pulsar.service
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
    change_plot)
        update_farm_size
        ;;
    show_info)
        print_node_info
        ;;
    logs)
        logs
        ;;
    check_sync)
        check_sync
        ;;
    install)
        install_node
        ;;
    uninstall)
        uninstall_node
        ;;
    help)
        usage
        ;;
    update)
        update_node

        echo "После обновления..." # Добавим это отладочное сообщение
        
        if [[ $2 == "-w" ]]; then
            if [[ -z $3 ]]; then
                echo "Аргумент -w требует значение (all, farmer или node)."
                exit 1
            fi
            wipe_choice $3
        fi
        ;;
    *)
        usage
        ;;
esac
