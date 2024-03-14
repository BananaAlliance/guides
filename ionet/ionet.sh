#!/bin/bash

# Устанавливаем цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Проверяем версию Ubuntu
echo -e "${GREEN}Проверка версии Ubuntu...${NC}"
VERSION=$(lsb_release -r | awk '{ print $2 }')
if [ "$VERSION" = "20.04" ]; then
    echo -e "${GREEN}Проверка пройдена. Версия Ubuntu 20.04.${NC}"
else
    echo -e "${RED}Ошибка: Этот скрипт требует Ubuntu 20.04. Выход.${NC}"
    exit 1
fi

# Обновление списка пакетов и установленных пакетов
echo -e "${GREEN}Обновление списка пакетов...${NC}"
sudo apt update && sudo apt -y upgrade
echo -e "${GREEN}Обновление завершено.${NC}"

# Установка io-net
echo -e "${GREEN}Установка io-net...${NC}"
curl -L https://github.com/ionet-official/io-net-official-setup-script/raw/main/ionet-setup.sh -o ionet-setup.sh
sudo apt install -y curl
chmod +x ionet-setup.sh && ./ionet-setup.sh
echo -e "${GREEN}io-net установлен.${NC}"

# Загрузка и установка launch_binary
echo -e "${GREEN}Загрузка и установка launch_binary...${NC}"
curl -L https://github.com/ionet-official/io_launch_binaries/raw/main/launch_binary_linux -o launch_binary_linux
chmod +x launch_binary_linux
echo -e "${GREEN}launch_binary установлен.${NC}"

echo -e "${GREEN}Все процессы завершены успешно!${NC}"


