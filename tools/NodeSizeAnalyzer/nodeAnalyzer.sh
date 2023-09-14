#!/bin/bash

# Цвета для красивого вывода
GREEN='\033[0;32m'
NC='\033[0m' # Нет цвета
CYAN='\033[0;36m'
RED='\033[0;31m'

declare -A nodes

# Список нод и их директорий
nodes["Subspace"]="$HOME/.local/share/pulsar/"
nodes["Gear"]="$HOME/.local/share/gear/"
nodes["Fleek"]="/root/.lightning/ /root/fleek-network/"
nodes["Elixir"]="/root/elixir/"
nodes["Massa"]="/root/massa/"
nodes["Namada"]="/root/.namada/"
nodes["Penumbra"]="/root/penumbra/"
nodes["Shardeum"]="/root/.shardeum/"
nodes["Kroma"]="/root/kroma-up/"
nodes["Holograph"]="/root/.config/holograph"
nodes["Minima"]="/root/minimadocker*"

# Проверка на наличие утилиты bc
ensure_bc_installed() {
    if ! command -v bc &> /dev/null; then
        echo "Утилита bc не найдена. Пытаюсь установить..."
        sudo apt update && sudo apt install -y bc
        if [ $? -ne 0 ]; then
            echo "Не удалось установить bc. Прерывание выполнения скрипта."
            exit 1
        fi
    fi
}

# Анализатор размера нод
node_size_analyzer() {
    # Получаем информацию о диске
	total_space=$(df --output=size -BG $HOME | tail -1 | tr -d 'G ')
	used_space=$(df --output=used -BG $HOME | tail -1 | tr -d 'G ')

	# Шапка
	echo -e "${GREEN}======================================="
	echo -e "Размеры директорий и имена нод:"
	echo -e "=======================================${NC}"

	total_size_nodes=0

	# Перебор всех нод в ассоциативном массиве
	for node in "${!nodes[@]}"; do
	    total_size_for_node=0
	    not_found=0

	    IFS=' ' # Устанавливаем разделитель на пробел
	    for dir in ${nodes[$node]}; do
	        if [ -d "$dir" ]; then
	            size=$(du -sBG "$dir" | awk '{print $1}' | tr -d 'G ')
	            total_size_for_node=$(($total_size_for_node + $size))
	        else
	            not_found=1
	        fi
	    done
	    total_size_nodes=$(($total_size_nodes + $total_size_for_node))

	    # Вычисляем процентное соотношение
	    percentage=$(echo "scale=2; ($total_size_for_node/$total_space)*100" | bc)

	    if [ $not_found -eq 0 ]; then
	        echo -e "${CYAN}${node}${NC}: ${GREEN}${total_size_for_node}GB (${percentage}%)${NC}"
	    fi
	done

	percentage_used_nodes=$(echo "scale=2; ($total_size_nodes/$total_space)*100" | bc)

	echo -e "${GREEN}======================================="
	echo -e "Общий размер диска: ${total_space}GB"
	echo -e "Использованное пространство: ${used_space}GB"
	echo -e "Общий размер всех нод: ${total_size_nodes}GB (${percentage_used_nodes}%)"
	echo -e "=======================================${NC}"
}
	

# Поиск крупных файлов
find_large_files() {
    echo -e "${GREEN}Ищем крупные файлы больше 100MB...${NC}"
    find / -type f -size +100M -exec du -sh {} + 2>/dev/null | sort -rh
}

# Основная логика
main() {
    ensure_bc_installed

    if [[ "$1" == "analyze" ]]; then
        node_size_analyzer
    elif [[ "$1" == "large_files" ]]; then
        find_large_files
    else
        echo -e "${RED}Укажите действие: 'analyze' для анализа нод или 'large_files' для поиска крупных файлов.${NC}"
    fi
}

main "$@"
