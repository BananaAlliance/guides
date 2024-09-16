#!/bin/bash

# Проверка root прав
if [[ $EUID -ne 0 ]]; then
   echo "⛔️ Пожалуйста, запустите этот скрипт с правами root." 
   exit 1
fi

# Эмодзи и цветной вывод для различных шагов
GREEN="\033[32m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

echo -e "${CYAN}🚀 Начало очистки Docker...${RESET}"

# Шаг 1: Очистка неактивных контейнеров
echo -e "${GREEN}🧹 Шаг 1: Удаление остановленных контейнеров...${RESET}"
sudo docker container prune -f
echo -e "${CYAN}✅ Остановленные контейнеры удалены.${RESET}"

# Шаг 2: Очистка неиспользуемых образов
echo -e "${GREEN}🧹 Шаг 2: Удаление неиспользуемых образов...${RESET}"
sudo docker image prune -a -f
echo -e "${CYAN}✅ Неиспользуемые образы удалены.${RESET}"

# Шаг 3: Очистка неиспользуемых томов
echo -e "${GREEN}🧹 Шаг 3: Удаление неиспользуемых томов...${RESET}"
sudo docker volume prune -f
echo -e "${CYAN}✅ Неиспользуемые тома удалены.${RESET}"

# Шаг 4: Очистка неиспользуемых сетей
echo -e "${GREEN}🧹 Шаг 4: Удаление неиспользуемых сетей...${RESET}"
sudo docker network prune -f
echo -e "${CYAN}✅ Неиспользуемые сети удалены.${RESET}"

# Шаг 5: Полная очистка неиспользуемых объектов
echo -e "${GREEN}🧹 Шаг 5: Полная очистка системы Docker...${RESET}"
sudo docker system prune -a --volumes -f
echo -e "${CYAN}✅ Полная очистка завершена.${RESET}"

# Шаг 6: Поиск и удаление больших неиспользуемых слоев
echo -e "${GREEN}🧹 Шаг 6: Поиск и удаление неиспользуемых больших слоев...${RESET}"
MIN_SIZE="+100M"
find /var/lib/docker/overlay2/ -type d -size $MIN_SIZE | while read dir; do
    layer_id=$(basename "$dir")
    
    # Проверяем, связан ли слой с контейнером
    container_check=$(sudo docker ps -a --filter "id=$layer_id" --format '{{.ID}}')
    
    if [[ -z "$container_check" ]]; then
        echo -e "📦 Слой ${layer_id} не используется. Удаляем..."
        sudo rm -rf "$dir"
        echo -e "${CYAN}✅ Слой ${layer_id} удалён.${RESET}"
    else
        echo -e "🔗 Слой ${layer_id} используется. Пропускаем..."
    fi
done

echo -e "${GREEN}🎉 Очистка Docker завершена!${RESET}"
