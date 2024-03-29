#!/bin/bash

# Проверка аргументов
if [[ -z $1 || -z $2 ]]; then
    echo "Ошибка: Не указаны необходимые аргументы. Используйте single, double, triple, quad или snapshot для первого аргумента и init или stop для второго."
    exit 1
fi

# Получение типа squid и действия из аргументов
SQUID_TYPE=$1
ACTION=$2


# Имя папки squid и URL репозитория
if [[ $SQUID_TYPE == "snapshot" ]]; then
    SQUID_NAME="my-snapshot-squid"
    REPO_URL="https://github.com/subsquid-quests/snapshot-squid"
    KEY_FILE="./query-gateway/keys/snapshot.key"  # Исправлено для snapshot
elif [[ $SQUID_TYPE == "cryptopunks" ]]; then
    SQUID_NAME="my-cryptopunks-squid"
    REPO_URL="https://github.com/subsquid-quests/cryptopunks-squid"
    KEY_FILE="./query-gateway/keys/cryptopunks.key"
elif [[ $SQUID_TYPE == "ens" ]]; then
    SQUID_NAME="my-ens-squid"
    REPO_URL="https://github.com/subsquid-quests/ens-squid"
    KEY_FILE="./query-gateway/keys/ens.key"
else
    SQUID_NAME="my-${SQUID_TYPE}-proc-squid"
    REPO_URL="https://github.com/subsquid-quests/${SQUID_TYPE}-chain-squid"
    KEY_FILE="./query-gateway/keys/${SQUID_TYPE}Proc.key"  # Обновлено для обработки snapshot
fi


# Путь к файлу ключа
if [[ $SQUID_TYPE == "snapshot" || $SQUID_TYPE == "cryptopunks" ]]; then
    KEY_FILE_NAME="${SQUID_TYPE}.key"
else
    KEY_FILE_NAME="${SQUID_TYPE}Proc.key"
fi
KEY_FILE="./query-gateway/keys/$KEY_FILE_NAME"


# Функция для проверки и установки Subsquid CLI
check_and_install_subsquid_cli() {
    if ! command -v node &> /dev/null; then
        echo "Node.js не установлен. Скачивание и установка Node.js..."
        wget -q -O install_nodejs.sh https://github.com/BananaAlliance/guides/raw/main/subsquid/install_nodejs.sh
        chmod +x install_nodejs.sh
        ./install_nodejs.sh
        rm install_nodejs.sh  # Удаление скрипта установки после использования
    fi

    if ! command -v sqd &> /dev/null; then
        echo "Установка Subsquid CLI..."
        npm install --global @subsquid/cli@latest
        echo -n "Проверка установки Subsquid CLI... "
        sqd --version
        sleep 2
    else
        echo "Subsquid CLI уже установлен."
    fi
}


# Функция для проверки наличия файла ключа
check_key_file() {
    while [[ ! -f $1 ]]; do
        echo "Файл ключа $1 не найден. Пожалуйста, скопируйте его в нужную папку."
        sleep 10  # Проверка каждые 10 секунд
    done
}

# Функция для инициализации и перехода в папку squid
init_and_cd_squid() {
    echo "Инициализация и переход в папку squid..."
    sqd init "$SQUID_NAME" -t "$REPO_URL"
    cd "$SQUID_NAME" || exit 1
}

# Функция для запуска Docker контейнеров
run_docker_containers() {
    echo "Запуск Docker контейнеров..."
    sqd up
    sleep 60  # Ожидание 1 минуты перед переходом к следующему шагу
}

# Функция для подготовки и запуска squid
prepare_and_run_squid() {
    echo "Подготовка и запуск squid..."
    npm ci
    sqd build
    sqd migration:apply
    sqd run .
}

# Функция для остановки и удаления вспомогательных контейнеров
stop_and_remove_containers() {
    echo "Остановка и удаление вспомогательных контейнеров..."
    sqd down
}

# Функция для запуска snapshot-squid
run_snapshot_squid() {
    echo "Инициализация и переход в папку squid..."
    if [[ -d $SQUID_NAME ]]; then
        echo "Папка $SQUID_NAME уже существует. Удалить и продолжить? (y/n)"
        read -r answer
        if [[ $answer == "y" ]]; then
            cd $HOME/my-snapshot-squid
            sqd down
            cd ..
            rm -rf "$SQUID_NAME"
        else
            echo "Операция отменена пользователем."
            exit 1
        fi
    fi
    sqd init "$SQUID_NAME" -t "$REPO_URL"
    cd "$SQUID_NAME" || exit 1

    check_key_file "$KEY_FILE"

    echo "Запуск Docker контейнеров..."
    sqd up
    sleep 60  # Ожидание 1 минуты перед переходом к следующему шагу

    echo "Подготовка и запуск squid..."
    npm ci
    sqd build
    sqd migration:apply
    sqd run .
    read -rp "После завершения синхронизации нажмите Enter, чтобы остановить и удалить вспомогательные контейнеров..."
    stop_and_remove_containers
}

# Функция для остановки squid
stop_squid() {
    echo "Остановка squid..."
    if [[ -d "/root/${SQUID_NAME}" ]]; then  # проверка существования папки
        cd "/root/${SQUID_NAME}" || exit 1
        sqd down
        cd "$HOME" || exit 1
    else
        echo "Ошибка: папка /root/${SQUID_NAME} не существует. Не удается остановить squid."
        exit 1
    fi
}

## Вызов функций в зависимости от типа squid
check_and_install_subsquid_cli

# Функция для клонирования и установки зависимостей subgraph
clone_and_setup_subgraph() {
    git clone https://github.com/subsquid-quests/simple-busd-subgraph
    cd simple-busd-subgraph || exit 1
    yarn install
}

# Функция для запуска Docker контейнеров subgraph
start_subgraph_containers() {
    docker compose up -d
    sleep 120  # Ожидание 2 минуты
}

# Функция для рандомизации и деплоя subgraph
deploy_subgraph() {
    yarn run randomize
    yarn run create-local
    yarn run deploy-local
}

# Функция для остановки Docker контейнеров subgraph
stop_subgraph_containers() {
    docker compose down
}

# Обновление основного блока выбора действий

if [[ $ACTION == "init" ]]; then
    if [[ $SQUID_TYPE == "snapshot" || $SQUID_TYPE == "cryptopunks" || $SQUID_TYPE == "ens" ]]; then
        init_and_cd_squid
        check_key_file "$KEY_FILE"
        run_docker_containers
        prepare_and_run_squid
        read -rp "После завершения синхронизации нажмите Enter, чтобы остановить и удалить вспомогательные контейнеров..."
        stop_and_remove_containers
    elif [[ $SQUID_TYPE == "subgraph" ]]; then
        clone_and_setup_subgraph
        check_key_file "./query-gateway/keys/busdSubgraph.key"
        start_subgraph_containers
        deploy_subgraph
    else
        echo "Ошибка: Неверный тип squid."
        exit 1
    fi
elif [[ $ACTION == "stop" ]]; then
    if [[ $SQUID_TYPE == "subgraph" ]]; then
        stop_subgraph_containers
    else
        stop_squid
    fi
else
    echo "Ошибка: Неверное действие. Используйте init или stop."
    exit 1
fi
