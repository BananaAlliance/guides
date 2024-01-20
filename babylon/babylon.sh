#!/bin/bash

LOGFILE="install_log.txt"

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

# Получение и установка имени ноды
get_nodename() {
  sed -i '/alias client/d' $HOME/.profile
  echo_colored "YELLOW" "Введите имя ноды (придумайте):"
  read BABYLON_MONIKER
  echo 'export BABYLON_MONIKER='$BABYLON_MONIKER >> $HOME/.profile
  log "Имя ноды установлено: $BABYLON_MONIKER"
}

# Установка Go
install_go() {
  if ! bash <(curl -s https://raw.githubusercontent.com/DOUBLE-TOP/tools/main/go.sh); then
    log "Ошибка: Не удалось установить Go."
    exit 1
  fi
  source $HOME/.profile
  sleep 1
  log "Go успешно установлен."
}

# Клонирование, проверка и сборка репозитория Babylon
source_build_git() {
  cd $HOME
  rm -rf babylon
  if ! git clone https://github.com/babylonchain/babylon.git; then
    log "Ошибка: Не удалось клонировать репозиторий Babylon."
    exit 1
  fi
  cd babylon
  git checkout v0.7.2
  make build
  log "Babylon успешно склонирован и собран."
  mkdir -p $HOME/.babylond/cosmovisor/genesis/bin
    mv build/babylond $HOME/.babylond/cosmovisor/genesis/bin/
    rm -rf build

    sudo ln -s $HOME/.babylond/cosmovisor/genesis $HOME/.babylond/cosmovisor/current -f
    sudo ln -s $HOME/.babylond/cosmovisor/current/bin/babylond /usr/local/bin/babylond -f

    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0
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
 babylond config chain-id bbn-test-2
    babylond config keyring-backend test
    babylond config node tcp://localhost:16457

    babylond init $BABYLON_MONIKER --chain-id bbn-test-2

    curl -Ls https://snapshots.kjnodes.com/babylon-testnet/genesis.json > $HOME/.babylond/config/genesis.json
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
    exit 1
  fi
  if ! sudo systemctl disable babylon; then
    log "Ошибка: Не удалось отключить службу Babylon."
    exit 1
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
  *)
    echo "Использование: $0 {install|uninstall}"
    exit 1
esac
