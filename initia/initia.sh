#!/bin/bash

function install_or_verify_initia {
    echo "Checking if initia is operational..."
    if ! initiad version &> /dev/null; then
        echo "initiad is not responding or not installed. Proceeding with installation or reinstallation..."
        
        # Удаляем старый каталог если он существует
        [ -d "initia" ] && rm -rf "initia"

        # Клонируем репозиторий
        if ! git clone https://github.com/initia-labs/initia.git; then
            echo "Failed to clone initia repository."
            exit 1
        fi

        # Переходим в каталог и выполняем установку
        cd initia
        if ! git checkout v0.2.12; then
            echo "Failed to checkout version v0.2.12."
            exit 1
        fi
        if ! make install; then
            echo "Installation script failed."
            exit 1
        fi
        cd $HOME

        # Проверяем работоспособность initiad снова
        if ! initiad version &> /dev/null; then
            echo "Installation of initiad failed or initiad version command failed."
            exit 1
        fi
    fi
    echo "initia is installed and operational. initiad version:"
    initiad version
}

function install_node {
    # Чтение имени ноды
    local NODE_MONIKER=""
    read -p "Enter your node's name: " NODE_MONIKER

    # Обновление и установка пакетов
    echo "Updating and installing required packages..."
    sudo apt update
    sudo apt install curl git jq build-essential gcc unzip wget lz4 -y

    # Установка Go
    echo "Installing Go..."
    local required_ver="go1.22.0"
    local current_ver=$(go version 2>/dev/null | grep -oP '^go version go\K[\d\.]+')
    if [ "$current_ver" = "$required_ver" ]; then
        echo "Required Go version $required_ver is already installed."
    else
        echo "Installing Go version $required_ver..."
        cd $HOME
        local ver="1.22.0"
        wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
        rm "go$ver.linux-amd64.tar.gz"
        echo "export PATH=/usr/local/go/bin:$PATH:$HOME/go/bin" >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version
    fi

    install_or_verify_initia

    # Настройка переменных окружения
    echo "Setting environment variables..."
    local profile=$HOME/.bash_profile
    grep -q 'export INITIA_MONIKER=' $profile || echo "export INITIA_MONIKER=\"$NODE_MONIKER\"" >> $profile
    grep -q 'export INITIA_CHAIN_ID=' $profile || echo 'export INITIA_CHAIN_ID="initiation-1"' >> $profile
    grep -q 'export INITIA_WALLET_NAME=' $profile || echo 'export INITIA_WALLET_NAME="wallet"' >> $profile
    grep -q 'export INITIA_RPC_PORT=' $profile || echo 'export INITIA_RPC_PORT="26657"' >> $profile
    source $profile

    # Инициализация ноды
    rm -rf /root/.initia/config/genesis.json
    
    echo "Initializing the node..."
    cd $HOME
    initiad init $INITIA_MONIKER --chain-id $INITIA_CHAIN_ID
    initiad config set client chain-id $INITIA_CHAIN_ID
    initiad config set client node tcp://localhost:$INITIA_RPC_PORT
    initiad config set client keyring-backend os

    # Скачивание genesis.json
    wget https://initia.s3.ap-southeast-1.amazonaws.com/initiation-1/genesis.json -O $HOME/.initia/config/genesis.json   
    
    # Добавление seeds и peers
    echo "Updating config.toml with new seeds and peers..."

    local PEERS="e3ac92ce5b790c76ce07c5fa3b257d83a517f2f6@178.18.251.146:30656,2692225700832eb9b46c7b3fc6e4dea2ec044a78@34.126.156.141:26656,2a574706e4a1eba0e5e46733c232849778faf93b@84.247.137.184:53456,40d3f977d97d3c02bd5835070cc139f289e774da@168.119.10.134:26313,1f6633bc18eb06b6c0cab97d72c585a6d7a207bc@65.109.59.22:25756,4a988797d8d8473888640b76d7d238b86ce84a2c@23.158.24.168:26656,e3679e68616b2cd66908c460d0371ac3ed7795aa@176.34.17.102:26656,d2a8a00cd5c4431deb899bc39a057b8d8695be9e@138.201.37.195:53456,329227cf8632240914511faa9b43050a34aa863e@43.131.13.84:26656,517c8e70f2a20b8a3179a30fe6eb3ad80c407c07@37.60.231.212:26656,07632ab562028c3394ee8e78823069bfc8de7b4c@37.27.52.25:19656,028999a1696b45863ff84df12ebf2aebc5d40c2d@37.27.48.77:26656,3c44f7dbb473fee6d6e5471f22fa8d8095bd3969@185.219.142.137:53456,8db320e665dbe123af20c4a5c667a17dc146f4d0@51.75.144.149:26656,c424044f3249e73c050a7b45eb6561b52d0db456@158.220.124.183:53456,767fdcfdb0998209834b929c59a2b57d474cc496@207.148.114.112:26656,edcc2c7098c42ee348e50ac2242ff897f51405e9@65.109.34.205:36656,140c332230ac19f118e5882deaf00906a1dba467@185.219.142.119:53456,4eb031b59bd0210481390eefc656c916d47e7872@37.60.248.151:53456,ff9dbc6bb53227ef94dc75ab1ddcaeb2404e1b0b@178.170.47.171:26656,ffb9874da3e0ead65ad62ac2b569122f085c0774@149.28.134.228:26656"
    local SEEDS="2eaa272622d1ba6796100ab39f58c75d458b9dbc@34.142.181.82:26656,c28827cb96c14c905b127b92065a3fb4cd77d7f6@testnet-seeds.whispernode.com:25756"

    sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.initia/config/config.toml

    # Получение внешнего IP-адреса
    EXTERNAL_IP=$(wget -qO- eth0.me)
    
    # Определение портов
    PROXY_APP_PORT=26658
    P2P_PORT=26656
    PPROF_PORT=6060
    API_PORT=1317
    GRPC_PORT=9090
    GRPC_WEB_PORT=9091
    
    # Обновление конфигурационного файла config.toml
    sed -i \
        -e "s/\(proxy_app = \"tcp:\/\/\)\([^:]*\):\([0-9]*\).*/\1\2:$PROXY_APP_PORT\"/" \
        -e "s/\(laddr = \"tcp:\/\/\)\([^:]*\):\([0-9]*\).*/\1\2:$INITIA_RPC_PORT\"/" \
        -e "s/\(pprof_laddr = \"\)\([^:]*\):\([0-9]*\).*/\1localhost:$PPROF_PORT\"/" \
        -e "/\[p2p\]/,/^\[/{s/\(laddr = \"tcp:\/\/\)\([^:]*\):\([0-9]*\).*/\1\2:$P2P_PORT\"/}" \
        -e "/\[p2p\]/,/^\[/{s/\(external_address = \"\)\([^:]*\):\([0-9]*\).*/\1${EXTERNAL_IP}:$P2P_PORT\"/; t; s/\(external_address = \"\).*/\1${EXTERNAL_IP}:$P2P_PORT\"/}" \
        $HOME/.initia/config/config.toml
    
    # Обновление конфигурационного файла app.toml
    sed -i \
        -e "/\[api\]/,/^\[/{s/\(address = \"tcp:\/\/\)\([^:]*\):\([0-9]*\)\(\".*\)/\1\2:$API_PORT\4/}" \
        -e "/\[grpc\]/,/^\[/{s/\(address = \"\)\([^:]*\):\([0-9]*\)\(\".*\)/\1\2:$GRPC_PORT\4/}" \
        -e "/\[grpc-web\]/,/^\[/{s/\(address = \"\)\([^:]*\):\([0-9]*\)\(\".*\)/\1\2:$GRPC_WEB_PORT\4/}" \
        $HOME/.initia/config/app.toml
    
    # Установка параметров обрезки (pruning)
    sed -i.bak -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.initia/config/app.toml
    sed -i.bak -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.initia/config/app.toml
    sed -i.bak -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.initia/config/app.toml
    
    # Установка минимальной стоимости газа
    sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.15uinit,0.01uusdc\"/" $HOME/.initia/config/app.toml
    
    # Установка типа индексации
    sed -i "s/^indexer *=.*/indexer = \"kv\"/" $HOME/.initia/config/config.toml

    # Настройка systemd сервиса и запуск ноды
    echo "Configuring and starting the node service..."
    sudo tee /etc/systemd/system/initiad.service > /dev/null <<EOF
[Unit]
Description=Initia Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which initiad) start --home $HOME/.initia
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable initiad
    sudo systemctl restart initiad

    echo "Node setup and launch script execution completed."
}

function snapshot {
    cd $HOME

    echo "Downloading latest snapshot from our endpoint..."
    wget https://snapshots.bwarelabs.com/initia/testnet/initia20240518.tar.lz4

    echo "Stopping the node..."
    sudo systemctl stop initiad

    echo "Backing up priv_validator_state.json..."
    cp $HOME/.initia/data/priv_validator_state.json $HOME/.initia/priv_validator_state.json.backup

    echo "Removing old data..."
    rm -rf $HOME/.initia/data

    mkdir $HOME/.initia/data

    echo "Extracting files from the archive..."
    lz4 -d -c ./initia20240518.tar.lz4 | tar -xf - -C $HOME/.initia

    echo "Restoring priv_validator_state.json..."
    mv $HOME/.initia/priv_validator_state.json.backup $HOME/.initia/data/priv_validator_state.json

    curl -Ls https://snapshots.kjnodes.com/initia-testnet/addrbook.json > $HOME/.initia/config/addrbook.json


    echo "Restarting the node..."
    sudo systemctl restart initiad

    echo "Node is restarting. Please ensure your node is fully synced before proceeding to the next steps."
}

function status {
    # Получение высоты последнего блока локальной ноды
    local local_height=$(initiad status | jq -r '.sync_info.latest_block_height')
    
    # Получение высоты последнего блока в сети
    local network_height=$(curl -s https://rpc.dinhcongtac221.fun/status | jq -r '.result.sync_info.latest_block_height')
    
    # Расчёт разницы между высотой сети и локальной высотой
    local blocks_left=$((network_height - local_height))
    
    # Вывод информации
    echo "Your node height: $local_height"
    echo "Network height: $network_height"
    echo "Blocks left: $blocks_left"
    
    # Проверка состояния синхронизации
    if [ "$blocks_left" -le 10 ]; then
        echo "The node is synchronized."
    else
        echo "The node is still syncing."
    fi
}


function uninstall_node {
    echo "You are about to uninstall the Initia node. This will stop the node service, disable it, and remove all related files."
    read -p "Are you sure you want to continue? (y/n): " confirmation

    if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
        echo "Uninstallation cancelled."
        return
    fi

    echo "Stopping Initia node service..."
    sudo systemctl stop initiad
    if [ $? -ne 0 ]; then
        echo "Failed to stop Initia node service."
    else
        echo "Initia node service stopped successfully."
    fi

    echo "Disabling Initia node service..."
    sudo systemctl disable initiad
    if [ $? -ne 0 ]; then
        echo "Failed to disable Initia node service."
    else
        echo "Initia node service disabled successfully."
    fi

    echo "Removing Initia node service configuration..."
    sudo rm /etc/systemd/system/initiad.service
    if [ $? -ne 0 ]; then
        echo "Failed to remove service configuration file."
    else
        echo "Service configuration file removed successfully."
    fi

    echo "Removing Initia node data directories..."
    rm -rf $HOME/.initia
    if [ $? -ne 0 ]; then
        echo "Failed to remove node data directories."
    else
        echo "Node data directories removed successfully."
    fi

    echo "Uninstallation completed."
}

# Обработка аргументов
case "$1" in
    install)
        install_node
        ;;
    snapshot)
        snapshot
        ;;
    status)
        status
        ;;
    uninstall_node)
        uninstall_node
        ;;
    *)
        echo "Usage: $0 {install|snapshot|status|uninstall_node}"
        exit 1
        ;;
esac