#!/bin/bash

# Путь к временному файлу для хранения логов
log_file="/tmp/ritual_log.txt"

# Бесконечный цикл для мониторинга
while true; do
    # Проверяем, есть ли активная сессия screen с именем ritual
    if screen -list | grep -q "ritual"; then
        # Создаем жесткую копию содержимого screen в файл
        screen -S ritual -X hardcopy $log_file
        
        # Получаем последние 100 строк из лога для анализа
        log_output=$(tail -n 100 $log_file)
        
        # Проверяем условия для перезапуска по содержимому лога
        if [[ "$log_output" == *"[error    ] Task exited: {'code': -32000, 'message': 'filter not found'} [__main__]"* ]] || 
           [[ "$log_output" == *"Exited main process"* ]]; then
            echo "Detected critical error in logs. Restarting Docker containers..."
            docker restart anvil-node
            docker restart hello-world
            docker restart deploy-node-1
            docker restart deploy-fluentbit-1
            docker restart deploy-redis-1
        fi
    else
        echo "Screen session 'ritual' not found. Checking again in 60 seconds..."
        # Здесь можно добавить команды для запуска сессии screen, если это необходимо
    fi

    # Пауза перед следующей итерацией цикла
    sleep 60
done

