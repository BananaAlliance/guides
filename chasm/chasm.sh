#!/bin/bash

install_dependencies() {
    echo -e "\e[34m🔧 Устанавливаем зависимости...\e[0m"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y ca-certificates curl ufw
    if ! command -v ufw &> /dev/null; then
        echo -e "\e[31m❌ Возникла проблема с установкой 'ufw'. Пожалуйста, установите 'ufw' вручную и снова запустите этот скрипт.\e[0m"
        echo -e "\e[32mДля установки 'ufw', используйте следующую команду:\e[0m"
        echo -e "\e[32msudo apt-get install ufw\e[0m"
        exit 1
    fi
}

install_docker() {
    echo -e "\e[34m🐳 Устанавливаем Docker...\e[0m"
    sudo install -m 0755 -d /etc/apt/keyrings
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin screen
}

install_ngrok() {
    echo -e "\e[34m🌐 Устанавливаем ngrok...\e[0m"
    if ! command -v ngrok &> /dev/null; then
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt update
        sudo apt install -y ngrok
    fi
}

configure_ngrok() {
    echo -e "\e[34m🔑 Настраиваем ngrok...\e[0m"
    echo -e "\e[33mВведите Authtoken для ngrok: \e[0m"
    read -p $'\e[33mAuthtoken: \e[0m' NGROK_AUTHTOKEN
    ngrok config add-authtoken $NGROK_AUTHTOKEN

    screen -ls | grep "ngrok_session" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit
    screen -dmS ngrok_session
    screen -S ngrok_session -p 0 -X stuff "ngrok http 3032\n"
}

prompt_user_input() {
    echo -e "\e[34m📝 Запрашиваем данные у пользователя...\e[0m"
    echo -e "\e[33mПожалуйста, введите необходимую информацию:\e[0m"
    read -p $'\e[33mВведите SCOUT_NAME (название вашей ноды, любые латинские символы): \e[0m' SCOUT_NAME
    read -p $'\e[33mВведите SCOUT_UID: \e[0m' SCOUT_UID
    read -p $'\e[33mВведите WEBHOOK_API_KEY: \e[0m' WEBHOOK_API_KEY
    read -p $'\e[33mВведите GROQ_API_KEY: \e[0m' GROQ_API_KEY
}


get_external_ip() {
    EXTERNAL_IP=$(curl -s ifconfig.me)
    if [ -z "$EXTERNAL_IP" ]; then
        echo -e "\e[31m❌ Не удалось получить внешний IP адрес.\e[0m"
        exit 1
    fi
    WEBHOOK_URL="http://${EXTERNAL_IP}:3032"
}

create_env_file() {
    get_external_ip
    echo -e "\e[34m📂 Создаем файл окружения...\e[0m"
    cd $HOME
    if [ ! -d "chasm" ]; then
        mkdir chasm
    else
        echo -e "\e[33m⚠️ Директория 'chasm' уже существует. Используем существующую директорию.\e[0m"
    fi
    cd chasm
    if [ -f ".env" ]; then
        echo -e "\e[33m⚠️ Файл '.env' уже существует. Перезаписываем файл.\e[0m"
    fi
    cat <<EOF > .env
PORT=3032
LOGGER_LEVEL=debug

# Chasm
ORCHESTRATOR_URL=https://orchestrator.chasm.net
SCOUT_NAME=$SCOUT_NAME
SCOUT_UID=$SCOUT_UID
WEBHOOK_API_KEY=$WEBHOOK_API_KEY
WEBHOOK_URL=$WEBHOOK_URL

# Chosen Provider (groq, openai)
PROVIDERS=groq
MODEL=gemma2-9b-it
GROQ_API_KEY=$GROQ_API_KEY

NODE_ENV=production
EOF
}

configure_firewall() {
    echo -e "\e[34m🔥 Настраиваем брандмауэр...\e[0m"
    sudo ufw allow 3032
}

run_docker_container() {
    echo -e "\e[34m🚀 Запускаем Docker контейнер...\e[0m"
    docker pull chasmtech/chasm-scout
    docker run -d --restart=always --env-file ./.env -p 3032:3032 --name scout chasmtech/chasm-scout
}

restart_node() {
    echo -e "\e[34m🔄 Перезапускаем ноду...\e[0m"
    docker stop scout
    docker rm scout
    docker run -d --restart=always --env-file ./.env -p 3032:3032 --name scout chasmtech/chasm-scout
}

main() {
    case $1 in
        install)
            install_dependencies
            install_docker
            install_ngrok
            configure_ngrok
            prompt_user_input
            create_env_file
            configure_firewall
            run_docker_container
            echo -e "\e[32m✅ Установка успешно завершена!\e[0m"
            echo -e "\e[31m⚠️ Если UFW включен, убедитесь, что ваш SSH порт открыт для доступа к серверу.\e[0m"
            ;;
        uninstall)
            echo -e "\e[34m🗑️ Удаляем ноду...\e[0m"
            docker stop scout
            docker rm scout
            sudo ufw delete allow 3032
            rm rf /root/chasm
            echo -e "\e[32m✅ Нода успешно удалена!\e[0m"
            ;;
        restart)
            restart_node
            echo -e "\e[32m✅ Нода успешно перезапущена!\e[0m"
            ;;
        *)
            echo -e "\e[31m⚠️ Неверная команда. Используйте 'install' для установки, 'uninstall' для удаления или 'restart' для перезапуска.\e[0m"
            exit 1
            ;;
    esac
}

main "$@"