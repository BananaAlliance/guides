#!/bin/bash

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"


function print_step() {
  echo -e "\033[1;34m==================================================\033[0m"
  echo -e "\033[1;33m$1\033[0m"
  echo -e "\033[1;34m==================================================\033[0m"
}

# Функция для отображения анимированного спиннера
function spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\\'
  echo -n " "
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Функция для отображения анимированного баннера
function print_banner() {
  echo "🌟🌟🌟 Добро пожаловать в установщик Allora Node 🌟🌟🌟"
  sleep 1
  echo "Этот скрипт поможет вам установить и настроить все необходимые компоненты."
  echo "Пожалуйста, следите за инструкциями на экране для лучшего опыта."
  echo ""
}

# Обработка ошибок с подробным сообщением
function handle_error() {
  local step=$1
  echo "⚠️ Произошла ошибка на этапе: '$step'"
  echo "Пожалуйста, обратитесь в чат поддержки Альянса нод для помощи."
  exit 1
}

# Загрузка настроек окружения
function load_environment() {
  source .profile || handle_error "Загрузка настроек окружения"
  print_step
  echo "🔄 Подготовка окружения... Пожалуйста, подождите."
}

# Функция для установки необходимых пакетов и Go
function install_essential_packages_and_go() {
    echo "🔄 Обновление списка пакетов..."
    sleep 2
    sudo apt update || handle_error "Не удалось обновить список пакетов"

    echo "📦 Установка необходимых пакетов..."
    sleep 2
    sudo apt install mc jq curl build-essential git wget git lz4 -y || handle_error "Ошибка установки необходимых пакетов"

    echo "🗑 Удаление старой версии Go (если она установлена)..."
    sleep 2
    sudo rm -rf /usr/local/go

    echo "📥 Скачивание и установка Go 1.22.4..."
    sleep 2
    curl https://dl.google.com/go/go1.22.4.linux-amd64.tar.gz | sudo tar -C /usr/local -zxvf - || handle_error "Ошибка установки Go"

    echo "⚙️ Добавление переменных окружения для Go..."
    {
        echo "export GOROOT=/usr/local/go"
        echo "export GOPATH=$HOME/go"
        echo "export GO111MODULE=on"
        echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin"
    } >> $HOME/.profile || handle_error "Не удалось обновить .profile с переменными Go"

    echo "🔄 Применение обновлений в .profile..."
    sleep 2
    source $HOME/.profile || handle_error "Не удалось применить обновления в .profile"

    echo "✅ Установка GO завершена успешно."
    sleep 2
}

# Установка Docker, если он не установлен
function install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "🐳 Обнаружено отсутствие Docker. Инициируем установку..."
    sudo install -m 0755 -d /etc/apt/keyrings
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin screen
    echo "🐳 Установка Docker завершена успешно."
    sleep 2
  else
    echo "🐳 Проверка завершена: Docker уже установлен."
    sleep 2
  fi
}

# Установка Go, если версия не соответствует требованиям
function install_go() {
  local required_major_version=1
  local required_minor_version=22

  if command -v go &> /dev/null; then
    local go_version=$(go version | awk '{print $3}' | cut -d 'o' -f 2)
    local major_version=$(echo "$go_version" | cut -d '.' -f 1)
    local minor_version=$(echo "$go_version" | cut -d '.' -f 2)

    if [[ "$major_version" -lt "$required_major_version" ]] || { [[ "$major_version" -eq "$required_major_version" ]] && [[ "$minor_version" -lt "$required_minor_version" ]]; }; then
      echo "🔧 Обновление Go необходимо для совместимости."
      install_essential_packages_and_go
      echo "🔧 Go успешно обновлен."
      sleep 2
    else
      echo "🔧 Проверка завершена: Требуемая версия Go уже установлена."
      sleep 2
    fi
  else
    echo "🔧 Go не найден. Начинаем установку..."
    sleep 2
    install_essential_packages_and_go
    echo "🔧 Установка Go завершена успешно."
    sleep 2
  fi
}

# Функция для клонирования репозитория или обновления, если он уже существует
function clone_or_update_repo() {
  local repo_path="$HOME/allora-chain"
  local repo_url="https://github.com/allora-network/allora-chain.git"

  echo "🔍 Проверка наличия репозитория по пути: $repo_path"
  if [ -d "$repo_path" ]; then
    echo "📁 Репозиторий уже существует. Попытка обновления..."
    cd "$repo_path" && git pull || handle_error "Обновление репозитория"
    echo "🔄 Репозиторий успешно обновлен."
    sleep 2
  else
    git clone "$repo_url" "$repo_path" && cd "$repo_path" || handle_error "Клонирование репозитория"
    echo "🎉 Репозиторий успешно склонирован."
    sleep 2
  fi
}

# Установка основной ноды
function install_node() {
  print_step
  echo "🚀 Начинаем установку основной ноды Allora..."
  install_docker
  install_go

  clone_or_update_repo && cd $HOME/allora-chain
  sed -i 's/^go 1.22.2$/go 1.22/' go.mod || handle_error "Обновление go.mod"
  make all || handle_error "Сборка проекта Allora"
  print_step
  echo "👷 Сборка проекта Allora завершена успешно."
  sleep 2

  # Проверка версии установленной ноды
  print_step

  if allorad version; then
    echo "✅ Установленная версия ноды: $(allorad version)"
    echo "🔑 Пожалуйста, введите seed фразу кошелька:"
    allorad keys add testkey --recover
    #echo "🔑 Пожалуйста, выполните следующую команду для создания кошелька:"
    #echo "    source .profile && allorad keys add testkey"
    #echo "📝 Сохраните сид-фразу, адрес и пароль для дальнейшего использования."
  else
    handle_error "Проверка версии ноды"
  fi
}

# Удаление ноды
function remove_node() {
  echo "🗑 Инициируем удаление основной ноды Allora..."
  rm -rf $HOME/allora-chain || handle_error "Удаление ноды"
  echo "🧹 Нода Allora успешно удалена."
}

# Настройка рабочих узлов (воркеров)
function setup_workers() {
  print_step
  echo "🔧 Настройка рабочих узлов для Allora..."
  echo "🔑 Введите сид-фразу для кошельков воркеров:"
  read seed_phrase

  # Настройка первого воркера
  setup_worker "worker1-10m" "worker1-10m" "$seed_phrase"

  # Настройка второго воркера
  setup_worker "worker2-24h" "worker2-24h" "$seed_phrase"

  # Настройка третьего воркера
  setup_worker "worker3-20m" "worker3-20m" "$seed_phrase"

  echo "🚀 Все рабочие узлы настроены и запущены."
}

function setup_worker() {
  local repo_url="https://github.com/nhunamit/basic-coin-prediction-node.git"
  local repo_dir="basic-coin-prediction-node"
  local worker_dir=$1
  local branch_name=$2
  local seed_phrase=$3

  # Проверка, существует ли уже директория
  if [ -d "$HOME/$worker_dir" ]; then
    echo "⚠️ Директория $worker_dir уже существует. Удалить её? (y/n):"
    read -r delete_dir
    if [ "$delete_dir" == "y" ]; then
      rm -rf "$HOME/$worker_dir" || handle_error "Удаление существующей директории $worker_dir"
    else
      echo "❌ Настройка прервана для $worker_dir. Пожалуйста, удалите директорию вручную и повторите попытку."
      return 1
    fi
  fi

  cd $HOME && git clone $repo_url || handle_error "Клонирование репозитория воркера"

  mv $repo_dir $worker_dir || handle_error "Переименование директории репозитория"

  cd $worker_dir || handle_error "Переход в директорию $worker_dir"

  git branch -a || handle_error "Просмотр доступных веток"

  git checkout $branch_name || handle_error "Переключение на ветку $branch_name"

  git branch -a || handle_error "Проверка текущей ветки"

  # Замена значений в config.json
  sed -i "s/\"addressKeyName\": \".*\"/\"addressKeyName\": \"testkey\"/" config.json || handle_error "Замена ключа addressKeyName в конфиге"
  sed -i "s/\"addressRestoreMnemonic\": \".*\"/\"addressRestoreMnemonic\": \"$seed_phrase\"/" config.json || handle_error "Замена сид-фразы в конфиге"

  chmod +x init.config 
  ./init.config

  docker compose up -d || handle_error "Запуск воркера.."

  cd $HOME
}


# Вывод логов
function show_logs() {
  echo "📜 Отображение логов работы ноды Allora..."
  docker compose logs -f worker || handle_error "Вывод логов воркера"
}

# Проверка статуса ноды
function check_node_status() {
  echo "🔄 Проверка статуса ноды Allora..."
  curl --location 'http://localhost:6000/api/v1/functions/execute' \
    --header 'Content-Type: application/json' \
    --data '{
      "function_id": "bafybeigpiwl3o73zvvl6dxdqu7zqcub5mhg65jiky2xqb4rdhfmikswzqm",
      "method": "allora-inference-function.wasm",
      "parameters": null,
      "topic": "1",
      "config": {
        "env_vars": [
          {
            "name": "BLS_REQUEST_PATH",
            "value": "/api"
          },
          {
            "name": "ALLORA_ARG_PARAMS",
            "value": "ETH"ƒ
          }
        ],
        "number_of_nodes": -1,
        "timeout": 10
      }
    }' || handle_error "Проверка статуса ноды"
}

# Главная функция для управления аргументами
function main() {
  print_banner
  local action="$1"

  case "$action" in
    "install")
      install_node
      ;;
    "status")
      check_node_status
      ;;
    "remove")
      remove_node
      ;;
    "setup_workers")
      setup_workers
      ;;
    "show-logs")
      show_logs
      ;;
    *)
      echo "⚠️ Указано неверное действие: $action. Доступные опции: 'install', 'remove', 'setup_workers', 'show-logs'"
      exit 2
      ;;
  esac
}

# Запускаем главную функцию с аргументами командной строки
main "$@"