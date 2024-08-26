#!/bin/bash

# Установка последней версии Python
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.12 python3.12-venv python3.12-dev python3-pip

# Создание директории для вашего проекта
PROJECT_DIR="/opt/my-python-service"
sudo mkdir -p $PROJECT_DIR
sudo chown $USER:$USER $PROJECT_DIR

# Скачивание Python-скрипта и requirements.txt
wget -O $PROJECT_DIR/rpc.py https://example.com/path/to/rpc.py
wget -O $PROJECT_DIR/requirements.txt https://example.com/path/to/requirements.txt

# Переход в директорию проекта
cd $PROJECT_DIR

# Установка зависимостей
python3.12 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Создание systemd unit файла
SERVICE_FILE="/etc/systemd/system/my-python-service.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=My Python Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/rpc.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# Перезагрузка systemd для обнаружения нового сервиса
sudo systemctl daemon-reload

# Включение и запуск сервиса
sudo systemctl enable my-python-service
sudo systemctl start my-python-service

echo "Скрипт завершен. Сервис my-python-service установлен и запущен."
