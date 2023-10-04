#!/bin/bash

# Обновление пакетов
sudo apt-get update

# Установка необходимых пакетов
sudo apt-get install -y ca-certificates curl gnupg

# Создание директории для ключа GPG Nodesource
sudo mkdir -p /etc/apt/keyrings

# Загрузка и импорт ключа GPG Nodesource
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

# Определение основного номера версии Node.js
NODE_MAJOR=20  # Вы можете изменить это значение на 16, 18 или 20 в зависимости от того, какую версию Node.js вы хотите установить

# Создание deb-репозитория
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

# Обновление пакетов и установка Node.js
sudo apt-get update
sudo apt-get install nodejs -y

# Проверка установленной версии Node.js
node -v

