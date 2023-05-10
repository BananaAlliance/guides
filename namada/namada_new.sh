#!/bin/bash

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

function main_tools {
  bash <(curl -s https://raw.githubusercontent.com/DOUBLE-TOP/tools/main/main.sh)
  sudo apt install curl tar wget clang pkg-config libssl-dev libclang-dev jq build-essential bsdmainutils git make ncdu gcc git jq chrony liblz4-tool -y
  sudo apt install -y uidmap dbus-user-session
}

function rust {
  bash <(curl -s https://raw.githubusercontent.com/DOUBLE-TOP/tools/main/rust.sh)
  source $HOME/.profile
}

function nodejs {
  bash <(curl -s https://raw.githubusercontent.com/DOUBLE-TOP/tools/main/node.sh)
}

function go {
  bash <(curl -s https://raw.githubusercontent.com/DOUBLE-TOP/tools/main/go.sh)
}

function NAMADA_NAME {
  if [ ! ${NAMADA_NAME} ]; then
  echo "Введите свое имя ноды(придумайте)"
  line
  read NAMADA_NAME
  fi
}

function vars {
  echo "export NAMADA_TAG=v0.15.1" >> ~/.bash_profile
  echo "export TM_HASH=v0.1.4-abciplus" >> ~/.bash_profile
  echo "export CHAIN_ID=public-testnet-7.0.3c5a38dc983" >> ~/.bash_profile
  echo "export VALIDATOR_ALIAS=$NAMADA_NAME" >> ~/.bash_profile
  echo "export WALLET=$NAMADA_NAME" >> ~/.bash_profile
  source ~/.bash_profile
}

# function build_namada {
#   cd $HOME
#   git clone https://github.com/anoma/namada
#   cd namada
#   git checkout $NAMADA_TAG
#   make build-release
#
# }
#
# function build_tendermint {
#     cd $HOME
#     git clone https://github.com/heliaxdev/tendermint
#     cd tendermint
#     git checkout $TM_HASH
#     make build
# }
#
# function copy_bin {
#   sudo cp "$HOME/tendermint/build/tendermint" /usr/local/bin/tendermint
#   sudo cp $HOME/namada/target/release/{namada,namadac,namadan,namadaw} /usr/local/bin/
# }

function wget_bin {
  sudo wget -O /usr/local/bin/namada https://doubletop-bin.ams3.digitaloceanspaces.com/namada/$NAMADA_TAG/namada
  sudo wget -O /usr/local/bin/namadac https://doubletop-bin.ams3.digitaloceanspaces.com/namada/$NAMADA_TAG/namadac
  sudo wget -O /usr/local/bin/namadan https://doubletop-bin.ams3.digitaloceanspaces.com/namada/$NAMADA_TAG/namadan
  sudo wget -O /usr/local/bin/namadaw https://doubletop-bin.ams3.digitaloceanspaces.com/namada/$NAMADA_TAG/namadaw
  sudo wget -O /usr/local/bin/tendermint https://doubletop-bin.ams3.digitaloceanspaces.com/namada/tendermint
  sudo chmod +x /usr/local/bin/{tendermint,namada,namadac,namadan,namadaw}
}

function join_network {
  cd $HOME
  namada client utils join-network --chain-id $CHAIN_ID
  wget https://github.com/heliaxdev/anoma-network-config/releases/download/${CHAIN_ID}/${CHAIN_ID}.tar.gz
  tar xvzf "$HOME/$CHAIN_ID.tar.gz"
  mkdir -p $HOME/.namada/${CHAIN_ID}/tendermint/config/
  wget -O $HOME/.namada/${CHAIN_ID}/tendermint/config/addrbook.json https://github.com/McDaan/general/raw/main/namada/addrbook.json
  sudo sed -i 's/0\.0\.0\.0:26656/0\.0\.0\.0:51656/g; s/127\.0\.0\.1:26657/127\.0\.0\.1:51657/g' /root/.namada/public-testnet*/config.toml
}

function systemd_namada {
  sudo tee /etc/systemd/system/namada.service > /dev/null <<EOF
[Unit]
Description=namada
After=network-online.target

[Service]
User=root
WorkingDirectory=$HOME/.namada
Environment=NAMADA_LOG=debug
Environment=NAMADA_TM_STDOUT=true
ExecStart=/usr/local/bin/namada --base-dir=$HOME/.namada node ledger run
StandardOutput=syslog
StandardError=syslog
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable namada
  sudo systemctl restart namada
}


NAMADA_NAME
echo "installing tools...."
main_tools
rust
nodejs
go
echo "set vars, build bin files"
vars
# build_namada
# build_tendermint
# copy_bin
wget_bin
echo "run fullnode"
join_network
systemd_namada
echo "fullnode started, next steps in the guide"