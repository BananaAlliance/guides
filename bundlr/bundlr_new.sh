#!/bin/bash

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"
sleep 1
echo "Packing soft"
echo "-----------------------------------------------------------------------------"
sleep 1
sudo apt update && sudo apt install curl -y &>/dev/null
sudo apt-get install curl wget jq libpq-dev libssl-dev build-essential pkg-config openssl ocl-icd-opencl-dev libopencl-clang-dev libgomp1 -y &>/dev/null
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/rust.sh | bash &>/dev/null
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/node.sh | bash &>/dev/null
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/docker.sh | bash &>/dev/null
source $HOME/.profile
source "$HOME/.cargo/env"
mkdir $HOME/bundlr
cd $HOME/bundlr
git clone --recurse-submodules https://github.com/Bundlr-Network/validator-rust.git
cd $HOME/bundlr/validator-rust && cargo run --bin wallet-tool create > wallet.json
sleep 1
echo "-----------------------------------------------------------------------------"
echo "Soft completed"
echo "-----------------------------------------------------------------------------"
sleep 1
echo "-----------------------------------------------------------------------------"
echo "Making environment"
echo "-----------------------------------------------------------------------------"
sudo tee <<EOF >/dev/null $HOME/bundlr/validator-rust/.env
PORT=2109
VALIDATOR_KEY=./wallet.json
BUNDLER_URL=https://testnet1.bundlr.network
GW_WALLET=./wallet.json
GW_CONTRACT=RkinCLBlY4L5GZFv8gCFcrygTyd5Xm91CzKlR6qxhKA
GW_ARWEAVE=https://arweave.testnet1.bundlr.network
EOF
cd $HOME/bundlr/validator-rust && docker-compose up -d
echo "-----------------------------------------------------------------------------"
echo "Starting node"
echo "-----------------------------------------------------------------------------"