#!/bin/bash

# Цветовая кодировка для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Без цвета

declare -A nodes
# Список нод и их директорий
nodes["Fleek"]="$HOME/.lightning/keystore/"
nodes["Gear"]="$HOME/.local/share/gear/chains/gear_staging_testnet_v7/network/"
nodes["Massa"]="/root/massa/massa-node/config/node_privkey.key,/root/massa/massa-client/wallets/"
nodes["Namada"]="/root/.local/share/namada/pre-genesis"
nodes["Shardeum"]="/root/.shardeum/"
nodes["Holograph"]="/root/.config/holograph"
nodes["Nibiru"]="/root/.nibid/config/priv_validator_key.json"
nodes["Subspace"]="$HOME/.local/share/pulsar/"
nodes["Elixir"]="$HOME/elixir"

declare -A exception_nodes
exception_nodes["Subspace"]="Для ноды Subspace бэкап файлов не требуется. Пожалуйста, храните вашу мнемоническую фразу в секрете."
exception_nodes["Elixir"]="Для ноды Elixir бэкап файлов не требуется. Держите ваш Private key от Metamask в секрете."
exception_nodes["Shardeum"]="Для ноды Shardeum бэкап файлов не требуется. Держите ваш Private key от Metamask в секрете."
exception_nodes["Holograph"]="Для ноды Holograph бэкап файлов не требуется. Держите ваш Private key от Metamask в секрете."

# Статистика
successful_backups=0
total_backup_size=0
errors_occurred=0
start_time=$(date +%s)

usage() {
    echo "Использование: $0 [backup|-d backup_dir|-l|-h]"
    echo "    backup    Запустить процесс бэкапа."
    echo "    -d        Указать директорию для бэкапов."
    echo "    -l        Показать список доступных нод."
    echo "    -h        Показать эту справку."
    exit 1
}

show_nodes() {
    echo "Доступные ноды для бэкапа:"
    for node in "${!nodes[@]}"; do
        echo "  $node"
    done
    exit 0
}

while getopts ":d:lh" opt; do
    case $opt in
        d)
            backup_dir="$OPTARG"
            ;;
        l)
            show_nodes
            ;;
        h)
            usage
            ;;
        \?)
            echo "Неверная опция: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Опция -$OPTARG требует аргумента." >&2
            usage
            ;;
    esac
done

# Если директория для бэкапов не указана, используем значение по умолчанию
if [ -z "$backup_dir" ]; then
    backup_dir="./BananaTools/backups/"
fi
mkdir -p $backup_dir


backup_node() {
    local node_name=$1
    local node_paths=$2
    local current_date=$(date "+%Y-%m-%d")

    echo ""
    echo ""
    echo -e "${CYAN}======== Обработка ноды: $node_name =======${NC}"
    echo ""
    sleep 1

    # Проверка на исключение
    if [[ -n "${exception_nodes[$node_name]}" ]]; then
        echo -e "${YELLOW}${exception_nodes[$node_name]}${NC}"
        return
    fi

    # Разделение путей на массив
    IFS=',' read -ra ADDR <<< "$node_paths"

    # Проверка существования всех путей
    for path in "${ADDR[@]}"; do
        if [[ ! -e $path ]]; then
            echo -e "${RED}Путь $path не найден. Пропуск.${NC}"
            errors_occurred=$((errors_occurred + 1))
            return
        fi
    done

    local archive_name="${backup_dir}${node_name}_backup_${current_date}.tar.gz"
    echo -e "${YELLOW}Создание бэкапа для ноды $node_name...${NC}"
    sleep 2

    # Создание бэкапа
    tar -czf "$archive_name" "${ADDR[@]}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Бэкап для $node_name успешно создан: $archive_name${NC}"
        successful_backups=$((successful_backups + 1))
        local size_bytes=$(du -sb "$archive_name" | awk '{print $1}')
        total_backup_size=$((total_backup_size + size_bytes))
    else
        echo -e "${RED}Ошибка при создании бэкапа для $node_name!${NC}"
        errors_occurred=$((errors_occurred + 1))
    fi
    sleep 1
}

# Функция для объединения всех архивов бэкапов в один архив
combine_archives() {
    local combined_archive_name="${backup_dir}combined_backups_$(date "+%Y-%m-%d").tar.gz"
    echo -e "${YELLOW}Объединение всех архивов бэкапов в один архив: $combined_archive_name${NC}"
    find "${backup_dir}" -maxdepth 1 -name "*.tar.gz" ! -name "combined_backups_*.tar.gz" | tar -czf "$combined_archive_name" -T -
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Все архивы бэкапов успешно объединены в: $combined_archive_name${NC}"
    else
        echo -e "${RED}Ошибка при объединении архивов!${NC}"
    fi
}



main() {
    echo -e "${CYAN}=== Инициализация процесса бэкапа ===${NC}"
    sleep 1.5

    for node in "${!nodes[@]}"; do
        backup_node "$node" "${nodes[$node]}"
    done

    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))

    echo ""
    echo -e "${CYAN}======= Статистика =======${NC}"
    sleep 1
    echo -e "${GREEN}Успешные бэкапы: $successful_backups${NC}"
    echo -e "${GREEN}Общий размер бэкапов: $(echo "scale=2; $total_backup_size / 1024 / 1024" | bc)MB${NC}"
    echo -e "${RED}Ошибок: $errors_occurred${NC}"
    echo -e "${YELLOW}Затраченное время: $elapsed_time секунд${NC}"

    echo ""
    echo -e "${GREEN}Все бэкапы сохранены в: $backup_dir${NC}"
    echo ""

    combine_archives

    echo ""

    echo -e "${CYAN}=== Процесс бэкапа завершен ===${NC}"

}

if [[ "$1" == "backup" ]]; then
    main
else
    usage
fi
