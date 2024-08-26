#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

# Функция для вывода заголовка шага
function print_step {
    echo -e "${BLUE}🔷 $1${NC}"
}

# Функция для вывода успешного завершения шага
function print_success {
    echo -e "${GREEN}✔ $1 успешно завершено${NC}"
}

# Функция для вывода ошибок
function print_error {
    echo -e "${RED}❌ Ошибка: $1${NC}"
    echo -e "${YELLOW}ℹ Как исправить: $2${NC}"
    exit 1
}

# Установка последней версии Python
print_step "Обновление списка пакетов и установка Python 3.12"
sudo apt update || print_error "Не удалось обновить список пакетов" "Проверьте подключение к интернету и повторите попытку."
sudo apt install -y software-properties-common || print_error "Не удалось установить software-properties-common" "Проверьте наличие пакетов и права доступа."
sudo add-apt-repository -y ppa:deadsnakes/ppa || print_error "Не удалось добавить PPA репозиторий" "Проверьте подключение к интернету и повторите попытку."
sudo apt update || print_error "Не удалось обновить список пакетов после добавления PPA" "Проверьте подключение к интернету и повторите попытку."
sudo apt install -y python3.12 python3.12-venv python3.12-dev python3-pip || print_error "Не удалось установить Python 3.12" "Проверьте наличие пакетов и права доступа."
print_success "Установка Python 3.12"

# Создание директории для вашего проекта
print_step "Создание директории для проекта"
PROJECT_DIR="/opt/my-python-service"
sudo mkdir -p $PROJECT_DIR || print_error "Не удалось создать директорию $PROJECT_DIR" "Проверьте права доступа."
sudo chown $USER:$USER $PROJECT_DIR || print_error "Не удалось изменить права на директорию $PROJECT_DIR" "Проверьте права доступа."
print_success "Создание директории"

# Скачивание Python-скрипта и requirements.txt
print_step "Скачивание Python-скрипта и requirements.txt"
wget -O $PROJECT_DIR/rpc.py https://github.com/BananaAlliance/guides/raw/main/allora/rpc.py || print_error "Не удалось скачать rpc.py" "Проверьте URL и подключение к интернету."
wget -O $PROJECT_DIR/requirements.txt https://github.com/BananaAlliance/guides/raw/main/allora/requirements.txt || print_error "Не удалось скачать requirements.txt" "Проверьте URL и подключение к интернету."
print_success "Скачивание файлов"

# Переход в директорию проекта
print_step "Переход в директорию проекта"
cd $PROJECT_DIR || print_error "Не удалось перейти в директорию $PROJECT_DIR" "Проверьте существование директории и права доступа."

# Установка зависимостей
print_step "Создание виртуального окружения и установка зависимостей"
python3.12 -m venv venv || print_error "Не удалось создать виртуальное окружение" "Убедитесь, что Python 3.12 установлен правильно."
source venv/bin/activate || print_error "Не удалось активировать виртуальное окружение" "Проверьте корректность установки и структуру проекта."
pip install -r requirements.txt || print_error "Не удалось установить зависимости" "Проверьте содержимое requirements.txt и подключение к интернету."
print_success "Установка зависимостей"

# Создание systemd unit файла
print_step "Создание systemd unit файла"
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

print_success "Создание systemd unit файла"

# Перезагрузка systemd для обнаружения нового сервиса
print_step "Перезагрузка systemd и запуск сервиса"
sudo systemctl daemon-reload || print_error "Не удалось перезагрузить systemd" "Проверьте права доступа и корректность systemd конфигурации."
sudo systemctl enable my-python-service || print_error "Не удалось включить сервис my-python-service" "Проверьте права доступа и корректность systemd конфигурации."
sudo systemctl start my-python-service || print_error "Не удалось запустить сервис my-python-service" "Проверьте логи для получения дополнительной информации."
print_success "Сервис my-python-service установлен и запущен"

echo -e "${GREEN}🎉 Скрипт завершен. Сервис my-python-service установлен и запущен.${NC}"