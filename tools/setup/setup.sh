#!/bin/bash

# Версия скрипта
SETUP_VERSION="1.0.0"

# Цвета для логирования
COLOR_RESET="\e[0m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_RED="\e[31m"
COLOR_BLUE="\e[34m"

# Логирование
log() {
    echo -e "$1"
}

# Обработка ошибок
handle_error() {
    log "${COLOR_RED}❌ Ошибка: $1${COLOR_RESET}"
    exit 1
}

# Функция для обновления системы
system_update_upgrade() {
    log "${COLOR_BLUE}🔄 Обновляем систему и пакеты...${COLOR_RESET}"
    sudo apt-get update -y || handle_error "Не удалось обновить пакеты"
    sudo apt-get upgrade -y || handle_error "Не удалось обновить систему"
    log "${COLOR_GREEN}✔️ Система успешно обновлена и все пакеты обновлены${COLOR_RESET}"
}

# Функция установки пакетов
install_packages() {
    PACKAGES_TO_INSTALL=("$@")
    log "${COLOR_YELLOW}📦 Устанавливаем необходимые пакеты: ${PACKAGES_TO_INSTALL[*]}...${COLOR_RESET}"

    for package in "${PACKAGES_TO_INSTALL[@]}"; do
        if ! dpkg -l | grep -qw "$package"; then
            log "${COLOR_BLUE}🔧 Устанавливаем $package...${COLOR_RESET}"
            sudo apt-get install -y "$package" || handle_error "Не удалось установить $package"
            log "${COLOR_GREEN}✔️ $package установлен успешно${COLOR_RESET}"
        else
            log "${COLOR_GREEN}✔️ $package уже установлен${COLOR_RESET}"
        fi
    done
}

# Функция установки Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        log "${COLOR_YELLOW}🐳 Docker не найден. Устанавливаем Docker...${COLOR_RESET}"
        sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
        sudo apt-get install -y ca-certificates curl gnupg lsb-release || handle_error "Не удалось установить зависимости для Docker"
        
        sudo mkdir -p /etc/apt/keyrings || handle_error "Не удалось создать директорию для ключей"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || handle_error "Не удалось загрузить ключи Docker"
        
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || handle_error "Не удалось добавить репозиторий Docker"
        
        sudo apt-get update -y || handle_error "Не удалось обновить список пакетов"
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || handle_error "Не удалось установить Docker"
        
        log "${COLOR_GREEN}✔️ Docker успешно установлен!${COLOR_RESET}"
    else
        log "${COLOR_GREEN}✔️ Docker уже установлен!${COLOR_RESET}"
    fi
}

# Обновленная функция установки Node.js с использованием NVM
install_nodejs() {
    if ! command -v nvm &> /dev/null; then
        log "${COLOR_BLUE}🔧 Устанавливаем NVM (Node Version Manager)...${COLOR_RESET}"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash || handle_error "Не удалось установить NVM"
        
        # Загружаем nvm в текущую сессию
        export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Не удалось загрузить NVM"
        
        log "${COLOR_GREEN}✔️ NVM успешно установлен!${COLOR_RESET}"
    else
        log "${COLOR_GREEN}✔️ NVM уже установлен!${COLOR_RESET}"
    fi

    # Установка Node.js версии 20 через NVM
    if ! nvm ls 20 &> /dev/null; then
        log "${COLOR_BLUE}🔧 Устанавливаем Node.js версии 20 через NVM...${COLOR_RESET}"
        nvm install 20 || handle_error "Не удалось установить Node.js версии 20"
        log "${COLOR_GREEN}✔️ Node.js версии 20 установлен успешно!${COLOR_RESET}"
    else
        log "${COLOR_GREEN}✔️ Node.js версии 20 уже установлен!${COLOR_RESET}"
    fi
}

# Функция установки Python
install_python() {
    if ! command -v python3 &> /dev/null; then
        log "${COLOR_BLUE}🔧 Устанавливаем Python...${COLOR_RESET}"
        sudo apt-get install -y python3 python3-pip || handle_error "Не удалось установить Python"
        log "${COLOR_GREEN}✔️ Python установлен успешно${COLOR_RESET}"
    else
        log "${COLOR_GREEN}✔️ Python уже установлен!${COLOR_RESET}"
    fi
}

# Основной процесс установки
main() {
    UPDATE_SYSTEM=false
    INSTALL_DOCKER=false
    INSTALL_NODEJS=false
    INSTALL_PYTHON=false
    INSTALL_PACKAGES=()

    # Пример использования флагов для включения нужных опций
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --update) UPDATE_SYSTEM=true ;;
            --docker) INSTALL_DOCKER=true ;;
            --nodejs) INSTALL_NODEJS=true ;;
            --python) INSTALL_PYTHON=true ;;
            --packages) shift; INSTALL_PACKAGES=("$@") ;;
        esac
        shift
    done

    # Выполняем обновление системы, если флаг указан
    if [ "$UPDATE_SYSTEM" = true ]; then
        system_update_upgrade
    fi

    # Устанавливаем Docker, если флаг указан
    if [ "$INSTALL_DOCKER" = true ]; then
        install_docker
    fi

    # Устанавливаем Node.js через NVM, если флаг указан
    if [ "$INSTALL_NODEJS" = true ]; then
        install_nodejs
    fi

    # Устанавливаем Python, если флаг указан
    if [ "$INSTALL_PYTHON" = true ]; then
        install_python
    fi

    # Устанавливаем указанные пакеты, если есть
    if [ "${#INSTALL_PACKAGES[@]}" -gt 0 ]; then
        install_packages "${INSTALL_PACKAGES[@]}"
    fi
}

# Запуск основного процесса
main "$@"
