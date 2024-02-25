#!/bin/bash

pgrep -f 'babylon' | xargs -r kill -9
pgrep -f 'babylond' | xargs -r kill -9


find / -type f -name '*babylon*' -exec rm -rf {} +
find / -type d -name '*babylon*' -exec rm -rf {} +
find / -type f -name '*babylond*' -exec rm -rf {} +
find / -type d -name '*babylond*' -exec rm -rf {} +

echo "Операция завершена."
