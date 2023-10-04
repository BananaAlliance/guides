#!/bin/bash

# Проверка аргумента
if [[ -z $1 ]]; then
    echo "Ошибка: Не указан тип squid. Используйте single, double, triple или quad."
    exit 1
fi

# Получение типа squid из аргумента
SQUID_TYPE=$1

# Имя папки squid
SQUID_NAME="my-${SQUID_TYPE}-proc-squid"

# URL репозитория
REPO_URL="https://github.com/subsquid-quests/${SQUID_TYPE}-chain-squid"

# Путь к файлу ключа
KEY_FILE="./query-gateway/keys/${SQUID_TYPE}Proc.key"  # Убрано ^

# Функция для проверки и установки Subsquid CLI
check_and_install_subsquid_cli() {
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

# Вызов функций
check_and_install_subsquid_cli
init_and_cd_squid
check_key_file "$KEY_FILE"
run_docker_containers
prepare_and_run_squid
read -rp "После завершения синхронизации нажмите Enter, чтобы остановить и удалить вспомогательные контейнеров..."
stop_and_remove_containers

