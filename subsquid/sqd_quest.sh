#!/bin/bash

# Проверка аргумента
if [[ -z $1 ]]; then
    echo "Ошибка: Не указан тип squid. Используйте single, double, triple, quad или snapshot."
    exit 1
fi

# Получение типа squid из аргумента
SQUID_TYPE=$1

# Имя папки squid и URL репозитория
if [[ $SQUID_TYPE == "snapshot" ]]; then
    SQUID_NAME="my-snapshot-squid"
    REPO_URL="https://github.com/subsquid-quests/snapshot-squid"
else
    SQUID_NAME="my-${SQUID_TYPE}-proc-squid"
    REPO_URL="https://github.com/subsquid-quests/${SQUID_TYPE}-chain-squid"
fi

# Путь к файлу ключа
KEY_FILE="./query-gateway/keys/${SQUID_TYPE^}Proc.key"  # Обновлено для обработки snapshot

# ... остальные функции ...

# Функция для запуска snapshot-squid
run_snapshot_squid() {
    echo "Инициализация и переход в папку squid..."
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

# Вызов функций в зависимости от типа squid
check_and_install_subsquid_cli
if [[ $SQUID_TYPE == "snapshot" ]]; then
    run_snapshot_squid
else
    init_and_cd_squid
    check_key_file "$KEY_FILE"
    run_docker_containers
    prepare_and_run_squid
    read -rp "После завершения синхронизации нажмите Enter, чтобы остановить и удалить вспомогательные контейнеров..."
    stop_and_remove_containers
fi
