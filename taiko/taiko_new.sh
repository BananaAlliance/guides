#!/bin/bash

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

echo "INSTALLING ARGUMENTS"
echo "-----------------------------------------------------------------------------"
sleep 1
# sed -i '/^export ALCHEMY_KEY=/d; /^export ALCHEMY_WS=/d; /^export TAIKO_KEY=/d' $HOME/.bash_profile
if [ ! $ALCHEMY_KEY ]; then
    read -p "PUT YOUR HTTP: " ALCHEMY_KEY
    echo 'YOUR HTTP: ' $ALCHEMY_KEY
fi
sleep 1
# echo 'export ALCHEMY_KEY='$ALCHEMY_KEY >> $HOME/.bash_profile
if [ ! $ALCHEMY_WS ]; then
    read -p "PUT YOUR WS: " ALCHEMY_WS
    echo 'YOUR WS: ' $ALCHEMY_WS
fi
sleep 1
# echo 'export ALCHEMY_WS='$ALCHEMY_WS >> $HOME/.bash_profile
if [ ! $TAIKO_KEY ]; then
    read -p "PUT YOUR PRIVATE KEY: " TAIKO_KEY
    echo 'YOUR KEY: ' $TAIKO_KEY
fi
sleep 1
# echo 'export TAIKO_KEY='$TAIKO_KEY >> $HOME/.bash_profile
source $HOME/.profile
source $HOME/.bash_profile

echo "-----------------------------------------------------------------------------"
echo "INSTALLING DEPENDANCES"
echo "-----------------------------------------------------------------------------"
bash <(curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/firsttools.sh) &>/dev/null
bash <(curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/docker.sh) &>/dev/null
echo "-----------------------------------------------------------------------------"
echo "CLONING REPO"
echo "-----------------------------------------------------------------------------"
git clone https://github.com/taikoxyz/simple-taiko-node.git
cd simple-taiko-node
cp .env.sample .env

echo "-----------------------------------------------------------------------------"
echo "MAKING ENV"
echo "-----------------------------------------------------------------------------"

sudo tee <<EOF >/dev/null $HOME/simple-taiko-node/.env
############################### DEFAULT #####################################
# Chain ID
CHAIN_ID=167004

# Exposed ports
PORT_L2_EXECTION_ENGINE_HTTP=18545
PORT_L2_EXECTION_ENGINE_WS=18546
PORT_L2_EXECTION_ENGINE_METRICS=16060
PORT_L2_EXECTION_ENGINE_P2P=31303
PORT_ZKEVM_CHAIN_PROVER_RPCD=19010
PORT_PROMETHEUS=19090
PORT_GRAFANA=13000

# Comma separated L2 execution engine bootnode URLs for P2P discovery bootstrap
BOOT_NODES=enode://af5c8bf434ad71c1713a30428f0d643be2639f550444a9630d3ce0980c0a68cdcc2a53146448021e451adc067fe50578b4955784adce25939d06ddb142954390@35.202.212.244:30303,enode://293ddcba31a117fad992b6be0ff01594e53cb2e89d85127c63a10019edd68a007e2a074209da7917537382c8157bb06e654e8cece855df622afdfd1fba0eb65d@34.71.225.47:30303,enode://91ebd6a0355582ffc224ac774f336a5d14b67dbca42559237995701dd0ec10b473a4d3a09914ff164743ae920a42395faac7ac2b2b057c237388fde2c88957ae@35.202.142.162:30303

# Taiko protocol contract addresses
TAIKO_L1_ADDRESS=0xAC9251ee97Ed8beF31706354310C6b020C35d87b
TAIKO_L2_ADDRESS=0x0000777700000000000000000000000000000001

# A L2 account private key for building throw-away L2 blocks, for more detailed information, please
# see whitepaper's 5.5.1 Invalid Blocks.
L2_THROWAWAY_BLOCK_BUILDER_PRIVATE_KEY=92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38 # LibAnchorSignature.K_GOLDEN_TOUCH_PRIVATEKEY

############################### REQUIRED #####################################
# L1 Sepolia RPC endpoints (you will need an RPC provider such as Alchemy or Infura--or, run a full Sepolia node yourself)
L1_ENDPOINT_HTTP=$ALCHEMY_KEY
L1_ENDPOINT_WS=$ALCHEMY_WS

############################### OPTIONAL #####################################
# If you want to be a prover who generates and submits zero knowledge proofs of proposed L2 blocks, you need to change
# ENABLE_PROVER to true and set L1_PROVER_PRIVATE_KEY.
ENABLE_PROVER=true
# An L1 account (with balance) private key which will send the TaikoL1.proveBlock transactions.
L1_PROVER_PRIVATE_KEY=$TAIKO_KEY
EOF

source $HOME/simple-taiko-node/.env
sleep 1
docker-compose up -d

echo "-----------------------------------------------------------------------------"
echo "NODE HAS STARTED"
echo "-----------------------------------------------------------------------------"