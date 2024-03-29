#!/bin/bash

DIR="$HOME/subspace-pulsar"
CONFIG_URL="https://github.com/BananaAlliance/guides/raw/main/subspace/config.sh"

update_plot_size() {
    local service_file="/etc/systemd/system/subspaced-farmer.service"

    # Запрос размера фермы у пользователя
    read -p "Укажите новый размер фермы (нажмите Enter, чтобы указать по умолчанию '2GB'): " PLOT_SIZE
    PLOT_SIZE=${PLOT_SIZE:-2GB}
    echo -e "\e[32mНовый размер вашей фермы: $PLOT_SIZE\e[39m"

    # Проверка наличия файла сервиса
    if [[ ! -f "$service_file" ]]; then
        echo "Файл $service_file не найден."
        return 1
    fi

    # Замена строки с размером фермы
    sudo sed -i "s/size=\".*\"/size=\"$PLOT_SIZE\"/" "$service_file"

    # Перезагрузка и перезапуск сервиса
    sudo systemctl daemon-reload
    sudo systemctl restart subspaced-farmer

    echo "Все готово. Размер фермы обновлен."
}

# Функция для проверки наличия команды
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

create_folders() {
    echo "Создание необходимых папок..."
    mkdir -p $DIR
    # Скачивание файла конфигурации
    wget -q -O $DIR/config.sh $CONFIG_URL
    source $DIR/config.sh

}

# Функция для анимации загрузки
animate_loading() {
    local spinstr='|/-\'
    local delay=0.1
    while :; do 
        for i in $(seq 0 3); do
            printf "\r%s" "${spinstr:$i:1}"
            sleep $delay
        done
    done
}

# Установка зависимостей
install_dependencies() {
    if ! command_exists curl; then
        echo "Установка Curl..."
        (sudo apt update && sudo apt install curl -y) & animate_loading
    fi
}

uninstall_node() {
            echo "Удаление ноды и фермера..."
            sudo systemctl stop subspaced subspaced-farmer &>/dev/null
            sudo rm -rf $HOME/.local/share/subspace*
            sudo rm -f /usr/local/bin/subspace-node /usr/local/bin/subspace-farmer  
}

# Функция обновления ноды и фермера
update_node_and_farmer() {
    echo -e "\e[34mНачало процесса обновления...\e[0m"
    sleep 2

    echo "Скачивание файла конфигурации..."
    animate_loading &
    local pid=$! # Сохранение PID анимации
    wget -q -O $DIR/config.sh $CONFIG_URL
    source $DIR/config.sh
    kill $pid
    sleep 2

    echo "Остановка сервисов..."
    animate_loading &
    pid=$!
    sudo systemctl stop subspaced subspaced-farmer
    kill $pid
    sleep 2

    echo "# Удаление старых исполняемых файлов..."
    animate_loading &
    pid=$!
    sudo rm -f /usr/local/bin/subspace-node /usr/local/bin/subspace-farmer
    kill $pid
    sleep 2

    echo "Скачивание и установка новых версий..."
    animate_loading &
    pid=$!
    wget -O $DIR/subspace-node $SUBSPACE_NODE_3H
    wget -O $DIR/subspace-farmer $SUBSPACE_FARMER_3H
    sudo chmod +x $DIR/subspace-node $DIR/subspace-farmer
    sudo mv $DIR/subspace-node /usr/local/bin/
    sudo mv $DIR/subspace-farmer /usr/local/bin/
    kill $pid
    sleep 2

    echo "Перезапуск сервисов..."
    animate_loading &
    pid=$!
    sudo systemctl daemon-reload
    sudo systemctl restart subspaced subspaced-farmer
    kill $pid
    tput cnorm # Восстановить курсор

    echo -e "\e[32mОбновление завершено!\e[0m"
}

check_status() {
    echo "==================================================="
    echo -e '\n\e[42mПроверка статуса ноды\e[0m\n' && sleep 1
    if [[ `service subspaced status | grep active` =~ "running" ]]; then
        echo -e "Узел Subspace \e[32mустановлен и работает\e[39m!"
        echo -e "Для проверки статуса ноды используйте команду \e[7msystemctl status subspaced \e[0m"
        echo -e "Нажмите \e[7mQ\e[0m для выхода из меню статуса"
    else
        echo -e "Узел Subspace \e[31mне установлен корректно\e[39m, пожалуйста, переустановите."
    fi
    echo "==================================================="
    echo -e '\n\e[42mПроверка статуса фермера\e[0m\n' && sleep 1
    if [[ `service subspaced-farmer status | grep active` =~ "running" ]]; then
        echo -e "Фермер Subspace \e[32mустановлен и работает\e[39m!"
        echo -e "Для проверки статуса фермера используйте команду \e[7msystemctl status subspaced-farmer \e[0m"
        echo -e "Нажмите \e[7mQ\e[0m для выхода из меню статуса"
    else
        echo -e "Фермер Subspace \e[31mне установлен корректно\e[39m, пожалуйста, переустановите."
    fi
}

function updateNetwork {
    echo "Останавливаю сервисы: subspaced.service и subspaced-farmer.service"
    sudo systemctl stop subspaced.service
    sudo systemctl stop subspaced-farmer.service

    echo "Очищаю директорию $HOME/.local/share/subspace-farmer"
    rm -rf $HOME/.local/share/subspace-farmer/*

    # Путь к файлу сервиса
service_file="/etc/systemd/system/subspaced.service"

# Чтение текущих значений --base-path и --name
base_path=$(grep 'ExecStart=' $service_file | sed -n 's/.*--base-path "\([^"]*\)".*/\1/p')
name=$(grep 'ExecStart=' $service_file | sed -n 's/.*--name \([^ ]*\).*/\1/p')

# Проверка, что значения были найдены
if [ -z "$base_path" ] || [ -z "$name" ]; then
    echo "Не удалось найти --base-path или --name в $service_file"
    exit 1
fi

# Создание нового файла конфигурации
echo "Создание нового файла конфигурации для subspaced.service с сохранением --base-path и --name"
cat <<EOF | sudo tee $service_file > /dev/null
[Unit]
Description=Subspace Node
After=network.target

[Service]
User=root
Type=simple
ExecStart=/usr/local/bin/subspace-node run --base-path "$base_path" --chain gemini-3h --farmer --name $name
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo "Конфигурация сервиса обновлена. Выполнение daemon-reload."
sudo systemctl daemon-reload

echo "Перезапуск сервисов subspaced и subspaced-farmer."
sudo systemctl restart subspaced.service
sudo systemctl restart subspaced-farmer.service

echo "Операция завершена успешно."
}

# Основной блок скрипта
case "$1" in
    install)
        create_folders
        install_dependencies
        bash_profile=$HOME/.bash_profile
        if [ -f "$bash_profile" ]; then
            . $HOME/.bash_profile
        fi
        sleep 1 && curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash && sleep 1

        read -p "Введите ваш farmer/reward адрес: " SUBSPACE_WALLET
        echo -e "\e[32mВаш адрес кошелька:\e[39m $SUBSPACE_WALLET"
        echo "=============================================================================================="

        read -p "Введите имя вашей ноды (без спецсимволов типа '.' и '@'): " SUBSPACE_NODENAME
        SUBSPACE_NODENAME=${SUBSPACE_NODENAME:-BananaNode}
        echo -e "\e[32mИмя вашего ноды:\e[39m $SUBSPACE_NODENAME"
        echo "=============================================================================================="

        read -p "Укажите путь для хранения файлов фермы (нажмте Enter, чтобы указать по умолчанию): " SUBSPACE_FARM_PATH
        SUBSPACE_FARM_PATH=${SUBSPACE_FARM_PATH:-$HOME/.local/share/subspace-farmer}
        echo -e "\e[32mПуть для файлов фермы:\e[39m $SUBSPACE_FARM_PATH"
        echo "=============================================================================================="

        read -p "Укажите путь для хранения файлов ноды (нажмте Enter, чтобы указать по умолчанию): " SUBSPACE_NODE_PATH
        SUBSPACE_NODE_PATH=${SUBSPACE_NODE_PATH:-$HOME/.local/share/subspace-node}
        echo -e "\e[32mПуть для файлов ноды:\e[39m $SUBSPACE_NODE_PATH"
        echo "=============================================================================================="

        read -p "Укажите размер фермы (нажмте Enter, чтобы указать по умолчанию '2GB'): " PLOT_SIZE
        PLOT_SIZE=${PLOT_SIZE:-2GB}
        echo -e "\e[32mРазмер вашей фермы:\e[39m $PLOT_SIZE"
        echo "=============================================================================================="

        sudo mkdir -p $SUBSPACE_FARM_PATH
        sudo mkdir -p $SUBSPACE_NODE_PATH
        echo ""
        echo -e "\e[32mИнформация сохранена.\e[39m"
        echo ""

        sudo apt update && sudo apt install ocl-icd-opencl-dev libopencl-clang-dev libgomp1 -y
        cd $HOME
        rm -rf subspace-node subspace-farmer
        wget -O subspace-node $SUBSPACE_NODE_3H
        wget -O subspace-farmer $SUBSPACE_FARMER_3H
        sudo chmod +x subspace-node subspace-farmer
        sudo mv subspace-node /usr/local/bin/
        sudo mv subspace-farmer /usr/local/bin/

        sudo systemctl stop subspaced subspaced-farmer &>/dev/null
        sudo rm -rf $HOME/.local/share/subspace*

        echo "[Unit]
Description=Subspace Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=/usr/local/bin/subspace-node run --base-path \"$SUBSPACE_NODE_PATH\" --chain gemini-3h --farmer --name $SUBSPACE_NODENAME
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > $HOME/subspaced.service

        echo "[Unit]
Description=Subspaced Farm
After=network.target

[Service]
User=$USER
Type=simple
TimeoutStartSec=infinity
ExecStartPre=/usr/bin/sleep 60
ExecStart=/usr/local/bin/subspace-farmer farm --reward-address $SUBSPACE_WALLET path=$SUBSPACE_FARM_PATH,size=\"$PLOT_SIZE\"
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > $HOME/subspaced-farmer.service

        sudo mv $HOME/subspaced.service /etc/systemd/system/
        sudo mv $HOME/subspaced-farmer.service /etc/systemd/system/
        sudo systemctl restart systemd-journald
        sudo systemctl daemon-reload
        sudo systemctl enable subspaced subspaced-farmer
        sudo systemctl restart subspaced
        sleep 20
        sudo systemctl restart subspaced-farmer

        echo "==================================================="
        echo -e '\n\e[42mПроверка статуса ноды\e[0m\n' && sleep 1
        check_status
        ;;
    uninstall)
        uninstall_node
        ;;
    change_plot)
        update_plot_size
        ;;
    update)
        update_node_and_farmer
        ;;    
    update_network)
        updateNetwork
        ;;
    check)
        check_status
        ;;
    *)
        echo "Использование: $0 {install|uninstall|check|change_plot}"
        ;;
esac
