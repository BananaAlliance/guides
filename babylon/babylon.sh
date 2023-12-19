#!/bin/bash

LOGFILE="install_log.txt"

# Функция для логирования
log() {
    echo "$1" | tee -a $LOGFILE
}

# Проверка успешности выполнения команды
check_success() {
    if [ $? -ne 0 ]; then
        log "Ошибка: $1"
        exit 1
    fi
}

# Установка Golang
install_golang() {
    log "Установка Golang..."
    if [ ! -f go1.21.5.linux-amd64.tar.gz ]; then
        wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
        check_success "Скачивание Golang не удалось."
    fi
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
    echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
    source ~/.bashrc
    go version &> /dev/null
    check_success "Установка Golang не удалась."
    log "Версия Golang: $(go version)"
}

# Установка Babylon
install_babylon() {
    log "Установка Babylon..."
    sudo apt install git build-essential curl jq --yes
    git clone https://github.com/babylonchain/babylon.git
    check_success "Клонирование репозитория Babylon не удалось."
    cd babylon
    git checkout 0.72
    make install
    check_success "Сборка Babylon не удалась."
    cd ..
}

# Инициализация директории ноды
initialize_node() {
    log "Инициализация директории ноды..."
    read -p "Введите название ноды: " NODENAME
    babylond init $NODENAME --chain-id bbn-test-2
    check_success "Инициализация ноды не удалась."
    wget https://github.com/babylonchain/networks/raw/main/bbn-test-2/genesis.tar.bz2
    tar -xjf genesis.tar.bz2 && rm genesis.tar.bz2
    mv genesis.json ~/.babylond/config/genesis.json
}

# Настройка конфигурации
configure_node() {
    log "Настройка конфигурации ноды..."

    CONFIG_TOML=~/.babylond/config/config.toml
    APP_TOML=~/.babylond/config/app.toml

    # Добавление или обновление seeds в config.toml
    SEEDS="8da45f9ff83b4f8dd45bbcb4f850999637fbfe3b@seed0.testnet.babylonchain.io:26656,4b1f8a774220ba1073a4e9f4881de218b8a49c99@seed1.testnet.babylonchain.io:26656"
    grep -q '\[p2p\]' $CONFIG_TOML && sed -i "/\[p2p\]/a seeds = \"$SEEDS\"" $CONFIG_TOML || echo -e "[p2p]\nseeds = \"$SEEDS\"" >> $CONFIG_TOML

    # Обновление параметров в app.toml
    grep -q '\[btc-config\]' $APP_TOML && sed -i '/\[btc-config\]/,/\[.*\]/s/network = .*/network = "mainnet"/' $APP_TOML || echo -e '[btc-config]\nnetwork = "mainnet"' >> $APP_TOML
    grep -q 'minimum-gas-prices' $APP_TOML && sed -i 's/minimum-gas-prices = .*/minimum-gas-prices = "0.00001ubbn"/' $APP_TOML || echo 'minimum-gas-prices = "0.00001ubbn"' >> $APP_TOML
}

# Установка Cosmovisor
install_cosmovisor() {
    log "Установка Cosmovisor..."
    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest
    check_success "Установка Cosmovisor не удалась."
    export PATH=$PATH:$(go env GOPATH)/bin
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
    source ~/.bashrc
    mkdir -p ~/.babylond/cosmovisor/genesis/bin
    mkdir -p ~/.babylond/cosmovisor/upgrades
    cp $(go env GOPATH)/bin/babylond ~/.babylond/cosmovisor/genesis/bin/babylond
    setup_cosmovisor_service
}

# Настройка службы Cosmovisor
setup_cosmovisor_service() {
    COSMOVISOR_PATH=$(go env GOPATH)/bin/cosmovisor
    if [ -f $COSMOVISOR_PATH ]; then
        sudo tee /etc/systemd/system/babylond.service > /dev/null <<EOF
[Unit]
Description=Babylon daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$COSMOVISOR_PATH run start --x-crisis-skip-assert-invariants
Restart=always
RestartSec=3
LimitNOFILE=infinity

Environment="DAEMON_NAME=babylond"
Environment="DAEMON_HOME=${HOME}/.babylond"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl start babylond
    else
        log "Ошибка: Cosmovisor не найден."
        exit 1
    fi
}

# Главная функция
main() {
    install_golang
    install_babylon
    initialize_node
    configure_node
    install_cosmovisor
    log "Автоматическая часть установки завершена. Пожалуйста, продолжите ручную настройку."
}

main
