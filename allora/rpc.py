import os
import json
import time
import requests

# Пути к директориям
directories = [
    "/root/worker1-10m",
    "/root/worker2-24h",
    "/root/worker3-20m"
]

# Список доступных RPC URL
rpc_list = [
    "https://allora-rpc.testnet-1.testnet.allora.network/",
    "https://beta.multi-rpc.com/allora_testnet/",
    "https://rpc.ankr.com/allora_testnet",
    "https://allora-testnet-1-rpc.testnet.nodium.xyz/"
]

# Функция для проверки доступности RPC
def check_rpc(rpc_url):
    try:
        response = requests.get(rpc_url, timeout=5)
        return response.status_code == 200
    except requests.RequestException:
        return False

# Функция для замены RPC во всех конфигурациях
def replace_rpc_in_all_directories(new_rpc):
    for directory in directories:
        config_path = os.path.join(directory, 'config.json')
        if os.path.exists(config_path):
            with open(config_path, 'r+') as f:
                config = json.load(f)
                config['wallet']['nodeRpc'] = new_rpc
                f.seek(0)
                json.dump(config, f, indent=4)
                f.truncate()
            print(f"RPC заменен на {new_rpc} в {config_path}")

# Основной цикл проверки и замены
def main():
    while True:
        replaced = False
        for directory in directories:
            config_path = os.path.join(directory, 'config.json')
            if os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    config = json.load(f)
                current_rpc = config['wallet']['nodeRpc']

                if not check_rpc(current_rpc):
                    # Ищем новый доступный RPC и заменяем
                    for rpc in rpc_list:
                        if rpc != current_rpc and check_rpc(rpc):
                            print(f"Замена RPC: {current_rpc} на {rpc} в {config_path}")
                            replace_rpc_in_all_directories(rpc)
                            replaced = True
                            break
                if replaced:
                    break

        # Пауза на 5 минут перед следующей проверкой
        time.sleep(300)

if __name__ == "__main__":
    main()
