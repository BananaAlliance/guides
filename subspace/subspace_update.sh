#!/bin/bash

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

function get_vars {
  export CHAIN="gemini-3d"
  export RELEASE="gemini-3d-2023-apr-24"
  export SUBSPACE_NODENAME=$(cat $HOME/subspace_docker/docker-compose.yml | grep "\-\-name" | awk -F\" '{print $4}')
  export WALLET_ADDRESS=$(cat $HOME/subspace_docker/docker-compose.yml | grep "\-\-reward-address" | awk -F\" '{print $4}')
  export PLOT_SIZE=$(cat $HOME/subspace_docker/docker-compose.yml | grep "\-\-plot-size" | awk -F\" '{print $4}')
}

function eof_docker_compose {
  sudo tee <<EOF >/dev/null $HOME/subspace_docker/docker-compose.yml
  version: "3.7"
  services:
    node:
      image: ghcr.io/subspace/node:$RELEASE
      volumes:
        - node-data:/var/subspace:rw
      ports:
        - "0.0.0.0:32333:30333"
        - "0.0.0.0:32433:30433"
      restart: unless-stopped
      command: [
        "--chain", "$CHAIN",
        "--base-path", "/var/subspace",
        "--execution", "wasm",
        "--blocks-pruning", "archive",
        "--state-pruning", "archive",
        "--port", "30333",
        "--dsn-listen-on", "/ip4/0.0.0.0/tcp/30433",
        "--rpc-cors", "all",
        "--rpc-methods", "safe",
        "--unsafe-ws-external",
        "--dsn-disable-private-ips",
        "--no-private-ipv4",
        "--validator",
        "--name", "$SUBSPACE_NODENAME",
        "--telemetry-url", "wss://telemetry.subspace.network/submit 0",
        "--out-peers", "100"
      ]
      healthcheck:
        timeout: 5s
        interval: 30s
        retries: 5

    farmer:
      depends_on:
        - node
      image: ghcr.io/subspace/farmer:$RELEASE
      volumes:
        - farmer-data:/var/subspace:rw
      ports:
        - "0.0.0.0:32533:30533"
      restart: unless-stopped
      command: [
        "--base-path", "/var/subspace",
        "farm",
        "--disable-private-ips",
        "--node-rpc-url", "ws://node:9944",
        "--listen-on", "/ip4/0.0.0.0/tcp/30533",
        "--reward-address", "$WALLET_ADDRESS",
        "--plot-size", "100G"
      ]
  volumes:
    node-data:
    farmer-data:
EOF
}

function update_subspace {
  cd $HOME/subspace_docker/
  docker-compose down
  eof_docker_compose
  docker-compose pull
  docker-compose up -d
}

get_vars
update_subspace
# check_verif
# line
echo -e "${GREEN}Update finished${NORMAL}"
cd $HOME