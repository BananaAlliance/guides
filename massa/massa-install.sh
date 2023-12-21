#!/bin/bash

# Установка начальных значений
function="install"
go_version="1.20.3"

# Функция для извлечения значения из параметра
option_value() {
    echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'
}

# Обработка входных параметров
while test $# -gt 0; do
    case "$1" in
        -in|--install)
            function="install"
            shift
            ;;
        -un|--uninstall)
            function="uninstall"
            shift
            ;;
        *|--)
            break
            ;;
    esac
done

# Функции
log_action() {
    echo "==> $1"
}

handle_error() {
    if [ $? -ne 0 ]; then
        echo "Ошибка: $1"
        exit 1
    fi
}

install_go() {
    log_action "Установка Go версии $go_version"
    wget "https://golang.org/dl/go$go_version.linux-amd64.tar.gz" &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Ошибка: Не удалось скачать Go"
        exit 1
    fi
    log_action "Скачивание Go завершено"

    sudo rm -rf /usr/local/go &> /dev/null
    sudo tar -C /usr/local -xzf "go$go_version.linux-amd64.tar.gz" &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Ошибка: Не удалось распаковать Go"
        exit 1
    fi
    log_action "Распаковка Go завершена"

    rm "go$go_version.linux-amd64.tar.gz" &> /dev/null
    log_action "Установка Go завершена"
}

setup_path() {
    log_action "Настройка переменных окружения для Go"
    echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
    source ~/.bash_profile
    log_action "Переменные окружения обновлены"
}


install() {
    sudo apt update &> /dev/null
    handle_error "Не удалось обновить список пакетов"
    cd $HOME

    if ! [ -x "$(command -v go)" ]; then
    log_action "Go не установлен, начинаем установку"
    install_go
    setup_path
    else
        log_action "Go уже установлен"
    fi


    [ ! -d ~/go/bin ] && mkdir -p ~/go/bin

    log_action "Клонирование и сборка masa-oracle-go-testnet"
    git clone https://github.com/masa-finance/masa-oracle-go-testnet.git
    cd masa-oracle-go-testnet
    go build -v -o masa-node ./cmd/masa-node &> /dev/null
    handle_error "Не удалось собрать masa-oracle-go-testnet"

    log_action "Настройка systemd сервиса для masa-node"
    sudo tee /etc/systemd/system/masa.service > /dev/null <<EOF
[Unit]
Description=Masa Node
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/masa-oracle-go-testnet/
ExecStart=$HOME/masa-oracle-go-testnet/masa-node \
        -port=8081 \
        --udp=true \
        --tcp=false \
        --start=true
Restart=always
RestartSec=10
LimitNOFILE=10000

[Install]
WantedBy=multi-user.target
EOF
    handle_error "Не удалось создать systemd сервис"

    sudo systemctl daemon-reload
    sudo systemctl enable masa
    sudo systemctl start masa
}

show_private_key() {
    log_action "Вывод приватного ключа"
    private_key_file="$HOME/.masa/masa_oracle_key.ecdsa"

    if [ -f "$private_key_file" ]; then
        private_key=$(cat "$private_key_file")
        echo "Ваш приватный ключ: 0x$private_key"
        echo ""
        echo "Внимание: Этот ключ необходимо импортировать в кошелек MetaMask."
        echo "Для этого откройте MetaMask, перейдите в раздел 'Импортировать аккаунт' и вставьте приватный ключ."
    else
        echo "Ошибка: Файл с приватным ключом не найден."
    fi
}


uninstall() {
    read -r -p "Вы действительно хотите удалить узел? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            log_action "Удаление masa-node"
            sudo systemctl stop masa
            sudo systemctl disable masa
            sudo rm /etc/systemd/system/masa.service 
            sudo systemctl daemon-reload
            sudo rm -rf $HOME/masa-oracle-go-testnet
            echo "Узел удален"
            ;;
        *)
            echo "Отменено"
            return 0
            ;;
    esac
}


# Обработка входных параметров
case "$1" in
    install)
        install
        show_private_key
        ;;
    uninstall)
        uninstall
        ;;
    show_private_key)
        show_private_key
        ;;
    *)
        echo "Использование: $0 {install|uninstall}"
        exit 1
        ;;
esac
