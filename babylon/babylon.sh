#!/bin/bash

LOGFILE="install_log.txt"
VERSION_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/babylon/babylon_version.txt"

# Функция для логирования
log() {
    echo "$1" | tee -a $LOGFILE
}

# Определение цветных кодов для вывода
setup_colors() {
  GREEN="\e[32m"
  RED="\e[31m"
  YELLOW="\e[33m"
  NORMAL="\e[0m"
}

# Вывод цветных сообщений
echo_colored() {
  echo -e "${!1}${2}${NORMAL}"
}

# Получение и отображение логотипа
logo() {
  if ! curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash; then
    log "Ошибка: Не удалось получить логотип."
    exit 1
  fi
  log "Логотип успешно загружен."
}

# Получение текущей версии babylond
get_current_version() {
  CURRENT_VERSION=$(babylond version)
  echo $CURRENT_VERSION
}

# Получение версии из файла на GitHub
get_version_from_github() {
  VERSION_URL="https://raw.githubusercontent.com/BananaAlliance/guides/main/babylon/babylon_version.txt"
  if ! VERSION=$(curl -s $VERSION_URL); then
    log "Ошибка: Не удалось получить версию из GitHub."
    exit 1
  fi
  echo $VERSION
}

# Получение и установка имени ноды
get_nodename() {
  # Попытка извлечь существующее имя ноды из .profile
  EXISTING_MONIKER=$(grep 'export BABYLON_MONIKER=' $HOME/.profile | cut -d'=' -f2)
  
  if [ -n "$EXISTING_MONIKER" ]; then
    echo_colored "YELLOW" "Текущее имя ноды: $EXISTING_MONIKER. Хотите изменить его? (yes/no):"
    read CHANGE_MONIKER
    
    if [ "$CHANGE_MONIKER" = "yes" ]; then
      echo_colored "YELLOW" "Введите новое имя ноды:"
      read BABYLON_MONIKER
      # Замена существующего имени ноды на новое
      sed -i "s/export BABYLON_MONIKER=$EXISTING_MONIKER/export BABYLON_MONIKER=$BABYLON_MONIKER/" $HOME/.profile
      log "Имя ноды изменено на: $BABYLON_MONIKER"
    else
      log "Имя ноды оставлено без изменений: $EXISTING_MONIKER"
    fi
  else
    echo_colored "YELLOW" "Введите имя ноды:"
    read BABYLON_MONIKER
    echo 'export BABYLON_MONIKER='$BABYLON_MONIKER >> $HOME/.profile
    log "Имя ноды установлено: $BABYLON_MONIKER"
  fi
}


# Установка Go
install_go() {
    echo "Обновление списка пакетов..."
    sudo apt-get update

    echo "Скачивание Go версии 1.21.0..."
    wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz

    echo "Распаковка архива Go..."
    sudo tar -xvf go1.21.0.linux-amd64.tar.gz

    echo "Перемещение Go в /usr/local..."
    sudo mv go /usr/local

    echo "Настройка переменных окружения для Go..."
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

    echo "Добавление переменных окружения в ~/.profile для будущих сессий..."
    echo 'export GOROOT=/usr/local/go' >> ~/.profile
    echo 'export GOPATH=$HOME/go' >> ~/.profile
    echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.profile

    echo "Go успешно установлен. Версия $(go version)."
    source ~/.profile
    echo "Заметьте, вам нужно будет выполнить 'source ~/.profile' или перезагрузить оболочку, чтобы применить изменения."
}

# Клонирование, проверка и сборка репозитория Babylon
source_build_git() {
  sudo apt install git build-essential curl jq --yes
  cd $HOME
  rm -rf babylon
  if ! git clone https://github.com/babylonchain/babylon.git; then
    log "Ошибка: Не удалось клонировать репозиторий Babylon."
    exit 1
  fi
  cd babylon
  log "Получаем последнюю версию.."
  if ! VERSION=$(curl -s $VERSION_URL); then
    log "Ошибка: Не удалось получить версию из GitHub."
  fi
  echo $VERSION
  git checkout $VERSION
  make build
  log "Babylon успешно склонирован и собран."
  mkdir -p $HOME/.babylond/cosmovisor/genesis/bin
    mv build/babylond $HOME/.babylond/cosmovisor/genesis/bin/
    rm -rf build

    sudo ln -s $HOME/.babylond/cosmovisor/genesis $HOME/.babylond/cosmovisor/current -f
    sudo ln -s $HOME/.babylond/cosmovisor/current/bin/babylond /usr/local/bin/babylond -f

    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0
}

update() {
  setup_colors
  if ! LATEST_VERSION=$(curl -s $VERSION_URL); then
    log "Ошибка: Не удалось получить версию из GitHub."
  fi

  CURRENT_VERSION=$(get_current_version)

  log "Текущая версия: $CURRENT_VERSION"
  log "Последняя версия: $LATEST_VERSION"

  if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    log "Обновление не требуется. У вас уже установлена последняя версия."
    exit 0
  else
    log "Начало обновления ноды Babylon."
    source_build_git
    sudo systemctl restart babylon.service
    log "Нода Babylon обновлена до версии $LATEST_VERSION."
  fi
}

# Настройка системной службы для ноды Babylon
setup_systemd() {
  sudo tee /etc/systemd/system/babylon.service > /dev/null << EOF
[Unit]
Description=babylon node service
After=network-online.target

[Service]
User=$USER
ExecStart=$HOME/go/bin/cosmovisor run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.babylond"
Environment="DAEMON_NAME=babylond"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.babylond/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable babylon.service
  log "Системная служба Babylon настроена."
}

# Инициализация блокчейна с указанными конфигурациями
init_chain() {
 babylond config chain-id bbn-test-3
    babylond config keyring-backend test
    babylond config node tcp://localhost:16457

    babylond init $BABYLON_MONIKER --chain-id bbn-test-3

    wget https://github.com/babylonchain/networks/raw/main/bbn-test-3/genesis.tar.bz2
    tar -xjf genesis.tar.bz2 && rm genesis.tar.bz2
    mv genesis.json ~/.babylond/config/genesis.json
    curl -Ls https://snapshots.kjnodes.com/babylon-testnet/addrbook.json > $HOME/.babylond/config/addrbook.json

    sed -i -e "s|^seeds *=.*|seeds = \"3f472746f46493309650e5a033076689996c8881@babylon-testnet.rpc.kjnodes.com:16459\"|" $HOME/.babylond/config/config.toml

    sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.00001ubbn\"|" $HOME/.babylond/config/app.toml

    sed -i \
    -e 's|^pruning *=.*|pruning = "custom"|' \
    -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
    -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
    -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
    $HOME/.babylond/config/app.toml

    sed -i -e "s|^timeout_commit *=.*|timeout_commit = \"10s\"|" $HOME/.babylond/config/config.toml

    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:16458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:16457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:16460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:16456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":16466\"%" $HOME/.babylond/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:16417\"%; s%^address = \":8080\"%address = \":16480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:16490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:16491\"%; s%:8545%:16445%; s%:8546%:16446%; s%:6065%:16465%" $HOME/.babylond/config/app.toml

  log "Цепочка инициализирована."
}

# Скачивание и распаковка снапшота
download_snapshot() {
  curl -L https://snapshots.kjnodes.com/babylon-testnet/snapshot_latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.babylond
    [[ -f $HOME/.babylond/data/upgrade-info.json ]] && cp $HOME/.babylond/data/upgrade-info.json $HOME/.babylond/cosmovisor/genesis/upgrade-info.json
  log "Снапшот скачан и распакован."
}

# Запуск службы Babylon
start_babylon() {
  if ! sudo systemctl start babylon; then
    log "Ошибка: Не удалось запустить службу Babylon."
    exit 1
  fi
  log "Служба Babylon запущена."
}

# Удаление службы Babylon
uninstall_babylon() {
  if ! sudo systemctl stop babylon; then
    log "Ошибка: Не удалось остановить службу Babylon."
  fi
  if ! sudo systemctl disable babylon; then
    log "Ошибка: Не удалось отключить службу Babylon."
  fi
  sudo rm /etc/systemd/system/babylon.service
  sudo rm -rf $HOME/babylon
 sudo rm -rf $HOME/.babylond
  sudo systemctl daemon-reload
  log "Служба Babylon удалена."
}

# Главная функция для организации установки
install() {
  setup_colors
  logo
  get_nodename
  install_go
  source_build_git
  setup_systemd
  init_chain
  download_snapshot
  start_babylon
  log "Установка ноды Babylon успешно завершена."
}

# Главная функция для деинсталляции
uninstall() {
  setup_colors
  uninstall_babylon
  log "Деинсталляция ноды Babylon успешно завершена."
}

# Основное выполнение скрипта
case "$1" in
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  update)
    update
    ;;
  *)
    echo "Использование: $0 {install|uninstall|update}"
    exit 1
esac
