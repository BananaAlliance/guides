#!/bin/bash

# Определение цветов для вывода
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"
REPORT="report.txt"

# Инициализация рекомендаций
RECOMMENDATIONS=""

# Функция вывода заголовка
header() {
    echo -e "${YELLOW}==== $1 ====${NC}" | tee -a $REPORT
    sleep 1
}

# Анализ использования ЦПУ
analyze_cpu() {
    header "Анализ использования ЦПУ"
    
    CPU_USAGE=$(top -bn1 | grep load | awk '{printf "%.2f", $(NF-2)}')
    echo -e "Текущая загрузка ЦПУ: ${BLUE}$CPU_USAGE%${NC}" | tee -a $REPORT

    LOAD_AVERAGE=$(uptime | awk -F'[a-z]:' '{ print $2}')
    echo -e "Средняя загрузка ЦПУ: ${BLUE}$LOAD_AVERAGE${NC}" | tee -a $REPORT

    echo "Топ-5 процессов по использованию ЦПУ:" | tee -a $REPORT
    ps -eo pid,%cpu,command --sort=-%cpu | head -n 6 | tee -a $REPORT
    echo

    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
        RECOMMENDATIONS+="\n- Рассмотрите возможность оптимизации или обновления оборудования. Ваш ЦПУ загружен более чем на 80%."
    fi
    sleep 1
}

# Анализ использования ОЗУ
analyze_memory() {
    header "Анализ использования ОЗУ"
    
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    USED_MEM=$(free -m | awk 'NR==2{print $3}')
    MEM_USAGE_PERCENT=$(awk "BEGIN { pc=100*${USED_MEM}/${TOTAL_MEM}; i=int(pc); print (pc-i<0.5)?i:i+1 }")

    echo -e "Общее использование ОЗУ: ${BLUE}$MEM_USAGE_PERCENT%${NC} (${USED_MEM}MB из ${TOTAL_MEM}MB)" | tee -a $REPORT

    echo "Топ-5 процессов по использованию ОЗУ:" | tee -a $REPORT
    ps -eo pid,%mem,command --sort=-%mem | head -n 6 | tee -a $REPORT
    echo

    if (( $MEM_USAGE_PERCENT > 80 )); then
        RECOMMENDATIONS+="\n- Рассмотрите возможность добавления памяти или оптимизации некоторых процессов. Ваша ОЗУ используется более чем на 80%."
    fi
    sleep 1
}

# Проверка температуры и частоты ЦПУ
cpu_temperature_and_frequency() {
    header "Проверка температуры и частоты ЦПУ"
    
    if ! command -v sensors &>/dev/null; then
        echo "Утилита 'sensors' не обнаружена. Попытка установки..."
        sudo apt-get install -y lm-sensors
        sudo sensors-detect --auto
    fi

    TEMP=$(sensors | grep 'Package id 0:' | awk '{print $4}' | sed 's/+//;s/°C//')
    echo -e "Температура ЦПУ: ${BLUE}$TEMP°C${NC}" | tee -a $REPORT

    CPU_FREQ=$(lscpu | grep "MHz" | awk '{print $3}')
    echo -e "Текущая частота ЦПУ: ${BLUE}$CPU_FREQ MHz${NC}" | tee -a $REPORT

    if (( $TEMP > 70 )); then
        RECOMMENDATIONS+="\n- Ваш ЦПУ нагревается выше нормы. Рассмотрите возможность улучшения системы охлаждения."
    fi
    sleep 1
}

# Анализ загрузки сетевого интерфейса
analyze_network() {
    header "Анализ загрузки сетевого интерфейса"

    INTERFACE=$(ip route | grep default | awk '{print $5}')
    RX_BEFORE=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
    TX_BEFORE=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
    sleep 2
    RX_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
    TX_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

    RX_RATE=$((($RX_AFTER - $RX_BEFORE) / 2))
    TX_RATE=$((($TX_AFTER - $TX_BEFORE) / 2))

    echo -e "Загрузка входящего трафика: ${BLUE}$RX_RATE байт/с${NC}" | tee -a $REPORT
    echo -e "Загрузка исходящего трафика: ${BLUE}$TX_RATE байт/с${NC}" | tee -a $REPORT

    if (( $RX_RATE > 5000000 || $TX_RATE > 5000000 )); then
        RECOMMENDATIONS+="\n- Ваша сеть активно используется. Убедитесь, что это ожидаемая активность. Возможно, стоит рассмотреть оптимизацию сетевого трафика."
    fi
    sleep 1
}

# Отображение рекомендаций
display_recommendations() {
    header "Рекомендации на основе анализа"

    if [ -z "$RECOMMENDATIONS" ]; then
        echo -e "${GREEN}На данный момент критических проблем не обнаружено.${NC}" | tee -a $REPORT
    else
        echo -e "$RECOMMENDATIONS" | tee -a $REPORT
    fi
}

if [[ "$1" == "analyze" ]]; then
    rm -f $REPORT
    touch $REPORT
    analyze_cpu
    analyze_memory
    cpu_temperature_and_frequency
    analyze_network
    display_recommendations
    echo -e "${GREEN}Отчет сохранен в файле report.txt${NC}"
else
    echo "Для проведения анализа, пожалуйста, запустите скрипт с аргументом 'analyze'. Пример: ./scriptname.sh analyze"
fi

