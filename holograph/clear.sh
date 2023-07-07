#!/bin/bash

echo "-----------------------------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------------------------"

echo "INSTALLING DEPENDANCES"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/firsttools.sh | bash &>/dev/null
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/node.sh | bash &>/dev/null

function install_cli {
    npm install -g @holographxyz/cli
}

function holograph_config {
    holograph config
}

function holograph_faucet {
    holograph faucet
}

function holograph_operator {
    holograph operator:bond
}

echo "INSTALLING DEPENDANCES"
echo "installation holograph_cli"
install_cli
echo "install config"
holograph_config
echo "faucet"
holograph_faucet
echo "bonding into a pod"
holograph_operator