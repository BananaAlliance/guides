#!/bin/bash

# Объявляем переменные
MONIKER_NAME=""
read -p "Enter your node's name: " MONIKER_NAME

# Функция для вывода и выполнения команд с проверкой результата
execute() {
    echo "$1"
    eval "$2"
    if [ $? -ne 0 ]; then
        echo "Error executing: $2"
        exit 1
    fi
}

# Обновление и установка пакетов
echo "Updating and installing required packages..."
sudo apt update
sudo apt install curl git jq build-essential gcc unzip wget lz4 -y

# Установка Go
echo "Installing Go..."

# Установка Go только если текущая версия не соответствует требуемой
required_ver="go1.21.3"
current_ver=$(go version 2>/dev/null | grep -oP '^go version go\K[\d\.]+')
if [ "$current_ver" = "$required_ver" ]; then
    echo "Required Go version $required_ver is already installed."
else
    echo "Installing Go version $required_ver..."
    cd $HOME
    ver="1.21.3"
    wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
    rm "go$ver.linux-amd64.tar.gz"
    echo "export PATH=/usr/local/go/bin:$PATH:$HOME/go/bin" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version
fi




# Проверка установлен ли уже evmosd и его версия
if command -v evmosd &> /dev/null && evmosd version &> /dev/null; then
    echo "evmosd is already installed."
    evmosd version
else
    echo "Building evmosd binary..."
    cd $HOME
    rm -rf 0g-evmos
    git clone https://github.com/0glabs/0g-evmos.git
    cd 0g-evmos
    git checkout v1.0.0-testnet
    make install
    evmosd version
fi


# Настройка переменных окружения, если они уже не настроены
if ! grep -q 'export MONIKER=' ~/.bash_profile; then
    echo "export MONIKER=\"$MONIKER_NAME\"" >> ~/.bash_profile
fi

if ! grep -q 'export CHAIN_ID=' ~/.bash_profile; then
    echo 'export CHAIN_ID="zgtendermint_9000-1"' >> ~/.bash_profile
fi

if ! grep -q 'export WALLET_NAME=' ~/.bash_profile; then
    echo 'export WALLET_NAME="wallet"' >> ~/.bash_profile
fi

if ! grep -q 'export RPC_PORT=' ~/.bash_profile; then
    echo 'export RPC_PORT="26657"' >> ~/.bash_profile
fi

source $HOME/.bash_profile


# Инициализация ноды
echo "Initializing the node..."
cd $HOME
evmosd init $MONIKER --chain-id $CHAIN_ID
evmosd config chain-id $CHAIN_ID
evmosd config node tcp://localhost:$RPC_PORT
evmosd config keyring-backend os

# Скачивание genesis.json
echo "Downloading genesis.json..."

wget https://github.com/0glabs/0g-evmos/releases/download/v1.0.0-testnet/genesis.json -O $HOME/.evmosd/config/genesis.json

# Добавление seeds и peers
echo "Adding seeds and peers to the config.toml..."

PEERS="1248487ea585730cdf5d3c32e0c2a43ad0cda973@peer-zero-gravity-testnet.trusted-point.com:26326" 
SEEDS="8c01665f88896bca44e8902a30e4278bed08033f@54.241.167.190:26656,b288e8b37f4b0dbd9a03e8ce926cd9c801aacf27@54.176.175.48:26656,8e20e8e88d504e67c7a3a58c2ea31d965aa2a890@54.193.250.204:26656,e50ac888b35175bfd4f999697bdeb5b7b52bfc06@54.215.187.94:26656" 
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.evmosd/config/config.toml
sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.00252aevmos\"/" $HOME/.evmosd/config/app.toml

# Настройка systemd сервиса и запуск ноды
echo "Configuring and starting the node service..."
sudo tee /etc/systemd/system/ogd.service > /dev/null <<EOF
[Unit]
Description=OG Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which evmosd) start --home $HOME/.evmosd
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ogd
sudo systemctl restart ogd

# Сообщение о завершении
echo "Node setup and launch script execution completed."
