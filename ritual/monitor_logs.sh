#!/bin/bash

# Путь к временному файлу для хранения логов
log_file="/tmp/ritual_log.txt"

# Бесконечный цикл для мониторинга
while true; do
    # Получаем последние 100 строк логов контейнера infernet-node
    docker logs --tail 100 infernet-node > $log_file
    log_output=$(cat $log_file)
    
    # Проверяем условия для перезапуска по содержимому лога
    if [[ "$log_output" == *"[error    ] Task exited: {'code': -32000, 'message': 'filter not found'} [__main__]"* ]] || 
       [[ "$log_output" == *"Exited main process"* ]]; then
        echo "Detected critical error in logs. Restarting Docker containers..."
        docker restart infernet-anvil
        docker restart infernet-node
        docker restart hello-world
        docker restart deploy-node-1
        docker restart deploy-fluentbit-1
        docker restart deploy-redis-1
    fi

    # Пауза перед следующей итерацией цикла
    sleep 60
done