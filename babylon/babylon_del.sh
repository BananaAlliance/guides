#!/bin/bash

# Найти и убить процессы, связанные с 'babylon' и 'babylond'
pgrep -f 'babylon' | xargs -r kill -9
pgrep -f 'babylond' | xargs -r kill -9

# Найти и удалить файлы и папки, содержащие 'babylon' и 'babylond' в их названиях
# ВНИМАНИЕ: Данная команда может быть опасной, так как она удалит все найденные файлы без подтверждения.
# Рекомендуется сначала выполнить команду без 'rm -rf' для проверки, какие файлы будут удалены.
find / -type f -name '*babylon*' -exec rm -rf {} +
find / -type d -name '*babylon*' -exec rm -rf {} +
find / -type f -name '*babylond*' -exec rm -rf {} +
find / -type d -name '*babylond*' -exec rm -rf {} +

echo "Операция завершена."
