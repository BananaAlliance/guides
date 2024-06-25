#!/bin/bash

# Скрипт управления нодой Nubit by Banana Alliance

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

# Функция вывода инструкции по использованию
usage() {
    echo "Использование: $0 {install|uninstall|check-balance|show-mnemonic|show-logs|get_address}"
    exit 1
}

# Функция задержки для визуального эффекта
delay() {
    sleep 1
}

# Функция проверки версии Ubuntu
check_ubuntu_version() {
    local version=$(lsb_release -rs)
    if [ "$version" != "22.04" ]; then
        echo -e "\e[1;31mЭтот скрипт предназначен для Ubuntu 22.04. Ваша версия: $version\e[0m"
        exit 1
    fi
}

# Функция для установки ноды Nubit
install_node() {
    echo -e "\e[1;34mНачало установки ноды Nubit...\e[0m"
    delay

    # Проверка, установлена ли уже нода
    if [ -d "$HOME/nubit-node" ]; then
        echo -e "\e[1;31mНода Nubit уже установлена. Завершение установки.\e[0m"
        exit 1
    fi

    # Проверка и закрытие уже запущенной screen сессии nubit
    if screen -list | grep -q "nubit"; then
        echo -e "\e[1;33mОбнаружена запущенная screen сессия nubit. Закрытие сессии...\e[0m"
        screen -S nubit -X quit
        delay
    fi

    echo "Обновление системных пакетов..."
    sudo apt update && sudo apt upgrade -y
    delay

    echo "Установка необходимых инструментов..."
    sudo apt install git screen vim ccze curl ufw python3-pip jq tar wget aria2 clang pkg-config libssl-dev build-essential -y
    delay

    echo "Настройка фаервола..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw enable
    delay

    echo "Установка ноды Nubit..."
    screen -dmS nubit
    screen -S nubit -p 0 -X stuff "curl -sL1 https://nubit.sh | bash$(printf \\r)"
    delay

    echo "Ожидание завершения установки и получение PUBKEY..."

    spinner="/-\|"
    spinpos=0
    pubkey=""
    while [ -z "$pubkey" ]; do
        screen -S nubit -p 0 -X hardcopy $HOME/nubit-node/nubit-installation-log.txt
        if [ -f "$HOME/nubit-node/nubit-installation-log.txt" ]; then
            pubkey=$(grep -A 1 "\*\* PUBKEY \*\*" $HOME/nubit-node/nubit-installation-log.txt | tail -n 1)
        fi
        spinpos=$(( (spinpos + 1) % 4 ))
        echo -ne "\r${spinner:spinpos:1}"
        sleep 0.2
    done
    echo ""

    echo -e "\e[1;32mУстановка ноды Nubit успешно завершена!\e[0m"
    echo -e "\e[1;34mВаш PUBKEY: $pubkey\e[0m"

    echo "Установка переменных среды..."
    if ! grep -q "export PATH=\$PATH:\$HOME/nubit-node/bin" ~/.bashrc; then
        echo "export PATH=\$PATH:\$HOME/nubit-node/bin" >> ~/.bashrc
    fi
    NETWORK=nubit-alphatestnet-1
    NODE_TYPE=light
    PEERS=/ip4/34.222.12.122/tcp/2121/p2p/12D3KooWJJWdaCB8GRMHuLiy1Y8FWTRCxDd5GVt6A2mFn8pryuf3
    VALIDATOR_IP=validator.nubit-alphatestnet-1.com
    GENESIS_HASH=AD1DB79213CA0EA005F82FACC395E34BE3CFCC086CD5C25A89FC64F871B3ABAE
    AUTH_TYPE=admin
    store=\$HOME/.nubit-\${NODE_TYPE}-\${NETWORK}/
    NUBIT_CUSTOM="\${NETWORK}:\${GENESIS_HASH}:\${PEERS}"
    if ! grep -q "export NETWORK=$NETWORK" ~/.bashrc; then
        echo "export NETWORK=$NETWORK" >> ~/.bashrc
    fi
    if ! grep -q "export NODE_TYPE=$NODE_TYPE" ~/.bashrc; then
        echo "export NODE_TYPE=$NODE_TYPE" >> ~/.bashrc
    fi
    if ! grep -q "export PEERS=$PEERS" ~/.bashrc; then
        echo "export PEERS=$PEERS" >> ~/.bashrc
    fi
    if ! grep -q "export VALIDATOR_IP=$VALIDATOR_IP" ~/.bashrc; then
        echo "export VALIDATOR_IP=$VALIDATOR_IP" >> ~/.bashrc
    fi
    if ! grep -q "export GENESIS_HASH=$GENESIS_HASH" ~/.bashrc; then
        echo "export GENESIS_HASH=$GENESIS_HASH" >> ~/.bashrc
    fi
    if ! grep -q "export AUTH_TYPE=$AUTH_TYPE" ~/.bashrc; then
        echo "export AUTH_TYPE=$AUTH_TYPE" >> ~/.bashrc
    fi
    if ! grep -q "export store=$store" ~/.bashrc; then
        echo "export store=$store" >> ~/.bashrc
    fi
    if ! grep -q "export NUBIT_CUSTOM=$NUBIT_CUSTOM" ~/.bashrc; then
        echo "export NUBIT_CUSTOM=$NUBIT_CUSTOM" >> ~/.bashrc
    fi
    source ~/.bashrc
}


# Функция для остановки ноды Nubit
stop_node() {
    echo -e "\e[1;34mОстановка ноды Nubit...\e[0m"
    delay

    # Проверка, установлена ли нода
    if [ ! -d "$HOME/nubit-node" ]; then
        echo -e "\e[1;31mНода Nubit не установлена. Пожалуйста, установите ноду перед перезапуском.\e[0m"
        exit 1
    fi

    # Закрытие запущенной screen сессии nubit
    if screen -list | grep -q "nubit"; then
        echo -e "\e[1;33mЗакрытие текущей screen сессии nubit...\e[0m"
        screen -S nubit -X quit
        delay
    fi


    echo -e "\e[1;32mОстановка ноды Nubit успешно завершена!\e[0m"
}


# Функция для перезапуска ноды Nubit
restart_node() {
    echo -e "\e[1;34mПерезапуск ноды Nubit...\e[0m"
    delay

    # Проверка, установлена ли нода
    if [ ! -d "$HOME/nubit-node" ]; then
        echo -e "\e[1;31mНода Nubit не установлена. Пожалуйста, установите ноду перед перезапуском.\e[0m"
        exit 1
    fi

    # Закрытие запущенной screen сессии nubit
    if screen -list | grep -q "nubit"; then
        echo -e "\e[1;33mЗакрытие текущей screen сессии nubit...\e[0m"
        screen -S nubit -X quit
        delay
    fi

    # Запуск новой screen сессии и выполнение скрипта
    echo "Запуск новой screen сессии и выполнение скрипта..."
    screen -dmS nubit
    screen -S nubit -p 0 -X stuff "curl -sL1 https://nubit.sh | bash$(printf \\r)"
    delay

    echo -e "\e[1;32mПерезапуск ноды Nubit успешно завершен!\e[0m"
}

# Функция для вывода логов
show_logs() {
    echo -e "\e[1;34mВывод логов ноды Nubit...\e[0m"

    if [ ! -d "$HOME/nubit-node" ]; then
        echo -e "\e[1;31mНода Nubit не установлена. Пожалуйста, установите ноду перед выводом логов.\e[0m"
        exit 1
    fi

    screen -S nubit -p 0 -X hardcopy $HOME/nubit-node/nubit-logs.txt
    cat $HOME/nubit-node/nubit-logs.txt
}

# Функция для удаления ноды Nubit
uninstall_node() {
    echo -e "\e[1;34mУдаление ноды Nubit...\e[0m"
    delay

    if [ ! -d "$HOME/nubit-node" ]; then
        echo -e "\e[1;31mНода Nubit не установлена. Нечего удалять.\e[0m"
        exit 1
    fi

    echo "Остановка screen сессии ноды Nubit..."
    screen -S nubit -X quit
    delay

    echo "Удаление директории nubit-node..."
    rm -rf ~/nubit-node $HOME/.nubit-light-nubit-alphatestnet-1 $HOME/.nubit-validator
    delay

    echo -e "\e[1;32mНода Nubit успешно удалена!\e[0m"
}

# Функция для получения адреса
get_address() {
    echo -e "\e[1;34mВывод адреса ноды Nubit...\e[0m"

    if [ ! -d "$HOME/nubit-node" ]; then
        echo -e "\e[1;31mНода Nubit не установлена. Пожалуйста, установите ноду.\e[0m"
        exit 1
    fi

    cd ~/nubit-node
    $HOME/nubit-node/bin/nubit state account-address --node.store $HOME/.nubit-light-nubit-alphatestnet-1
    echo -e "\e[1;34mДля получения токенов используйте кран: https://faucet.nubit.org/\e[0m"
}

# Функция для проверки баланса
check_balance() {
    echo -e "\e[1;34mПроверка баланса ноды Nubit...\e[0m"

    if [ ! -d "$HOME/nubit-node" ]; then
        echo -e "\e[1;31mНода Nubit не установлена. Пожалуйста, установите ноду перед проверкой баланса.\e[0m"
        exit 1
    fi

    cd ~/nubit-node
    $HOME/nubit-node/bin/nubit state balance --node.store $HOME/.nubit-light-nubit-alphatestnet-1
}

# Функция для вывода мнемоник фразы
show_mnemonic() {
    echo -e "\e[1;34mВывод мнемоник фразы...\e[0m"

    if [ ! -d "$HOME/nubit-node" ]; then
        echo -e "\e[1;31mНода Nubit не установлена. Пожалуйста, установите ноду перед выводом мнемоник фразы.\e[0m"
        exit 1
    fi

    if [ ! -f "$HOME/nubit-node/mnemonic.txt" ]; then
        echo -e "\e[1;31mФайл с мнемоник фразой не найден.\e[0m"
        exit 1
    fi

    cat $HOME/nubit-node/mnemonic.txt
}

# Основная логика скрипта
if [ $# -ne 1 ]; then
    usage
fi

check_ubuntu_version

case $1 in
    install)
        install_node
        ;;
    uninstall)
        uninstall_node
        ;;
    check-balance)
        check_balance
        ;;
    get_address)
        get_address
        ;;
    show-mnemonic)
        show_mnemonic
        ;;
    show-logs)
        show_logs
        ;;
    stop)
        stop_node
        ;;
    restart)
        restart_node
        ;;
    *)
        usage
        ;;
esac