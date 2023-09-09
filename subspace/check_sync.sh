#!/bin/bash

# Установим интервал обновления в 2 секунды
interval=8

# Предыдущий текущий блок (для расчета скорости)
previous_block=0

while true; do
    # Очистим терминал перед следующим обновлением
    clear

    # Находим самый последний файл логов
    latest_log_file=$(ls -t $HOME/.local/share/pulsar/logs | head -n 1)

    # Прочитать этот файл
    # Извлекаем информацию о текущем блоке и финальном блоке из последней строки файла логов
    last_line=$(tail -n 1 $HOME/.local/share/pulsar/logs/$latest_log_file)

    # Проверка на завершение синхронизации
    if [[ ! $last_line == *"Syncing"* ]]; then
        echo "Синхронизация завершилась или не выполняется"
        break
    fi

    current_block=$(echo $last_line | grep -o -E 'best: #([0-9]+)' | cut -d'#' -f2)
    target_block=$(echo $last_line | grep -o -E 'target=#([0-9]+)' | cut -d'#' -f2)

    # Проверяем, что мы получили нужные значения
    if [[ -z "$current_block" || -z "$target_block" ]]; then
        echo "Не удалось извлечь информацию из файла лога. Ждем обновления..."
        sleep $interval
        continue
    fi

    # Определить разницу
    difference=$((target_block - current_block))

    # Расчет скорости
    speed=$((current_block - previous_block))

    # Если скорость не 0, расчитываем оставшееся время
    if [ $speed -ne 0 ]; then
        time_left_seconds=$(($difference / $speed * $interval))
        time_left_hours=$(($time_left_seconds / 3600))
        time_left_minutes=$(($time_left_seconds % 3600 / 60))
        echo "Оставшееся время: примерно $time_left_hours часов $time_left_minutes минут"
    else
        echo "Синхронизация не продвигается"
    fi

    # Прогресс-бар
    progress=$((100 * $current_block / $target_block))
    bar_length=50
    progress_bar_length=$(($progress * $bar_length / 100))
    progress_bar=$(printf "%-${progress_bar_length}s" "=")
    spaces=$(printf "%-$(($bar_length - $progress_bar_length))s" " ")
    echo -e "Прогресс: [${progress_bar// /█}${spaces}] $progress%"

    echo "Текущий блок: $current_block"
    echo "Финальный блок: $target_block"
    echo "Оставшиеся блоки для синхронизации: $difference"

    # Запомнить текущий блок для следующей итерации
    previous_block=$current_block

    # Ждем N секунд перед следующим обновлением
    sleep $interval
done
