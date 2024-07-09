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
    curl -fsSL https://github.com/BananaAlliance/tools/raw/main/docker.sh -o get-docker.sh || handle_error "Скачивание скрипта установки Docker"
    sh get-docker.sh || handle_error "Установка Docker"
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
    echo "🔑 Пожалуйста, выполните следующую команду для создания кошелька:"
    echo "    source .profile && allorad keys add testkey"
    echo "📝 Сохраните сид-фразу, адрес и пароль для дальнейшего использования."
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

# Настройка рабочего узла (воркера)
function setup_worker() {
  print_step
  echo "🔧 Настройка рабочего узла для Allora..."
  echo "🔑 Введите сид-фразу для кошелька воркера:"
  read seed_phrase

  print_step

  cd $HOME && git clone https://github.com/allora-network/basic-coin-prediction-node || handle_error "Клонирование репозитория воркера"
  cd basic-coin-prediction-node

  mkdir worker-data head-data || handle_error "Создание директорий"
  sudo chmod -R 777 worker-data head-data || handle_error "Изменение прав доступа"

  sudo docker run -it --entrypoint=bash -v "$PWD/head-data:/data" alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)" &
  spinner $! || handle_error "Настройка head-data"
  sudo docker run -it --entrypoint=bash -v "$PWD/worker-data:/data" alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)" &
  spinner $! || handle_error "Настройка worker-data"

  sleep 10

  local head_id=$(cat head-data/keys/identity) || handle_error "Чтение идентификатора головы"
  rm -rf docker-compose.yml || handle_error "Удаление старого docker-compose.yml"
  wget https://github.com/BananaAlliance/guides/raw/main/allora/docker-compose.yml || handle_error "Загрузка нового docker-compose.yml"
  sed -i "s|ALLORA_HEAD_ID|$head_id|" docker-compose.yml || handle_error "Обновление файла конфигурации"
  sed -i "s|ALLORA_MNEMONIC|$seed_phrase|" docker-compose.yml || handle_error "Обновление файла конфигурации"

  docker compose build & spinner $! || handle_error "Сборка Docker контейнеров"
  docker compose up -d & spinner $! || handle_error "Запуск Docker контейнеров"

  print_step

  echo "🚀 Ваш рабочий узел настроен и запущен."
}

# Вывод логов
function show_logs() {
  echo "📜 Отображение логов работы ноды Allora..."
  docker compose -f $HOME/basic-coin-prediction-node/docker-compose.yml logs -f || handle_error "Вывод логов"
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
    "setup-worker")
      setup_worker
      ;;
    "show-logs")
      show_logs
      ;;
    *)
      echo "⚠️ Указано неверное действие: $action. Доступные опции: 'install', 'remove', 'setup-worker', 'show-logs'"
      exit 2
      ;;
  esac
}

# Запускаем главную функцию с аргументами командной строки
main "$@"