#!/bin/bash

echo "Downloading the latest snapshot..."
rm -rf latest_snapshot.tar.lz4*
wget https://rpc-zero-gravity-testnet.trusted-point.com/latest_snapshot.tar.lz4
if [ $? -ne 0 ]; then
    echo "Error downloading the latest snapshot"
    exit 1
fi

echo "Stopping the node..."
sudo systemctl stop ogd
if [ $? -ne 0 ]; then
    echo "Error stopping the node"
    exit 1
fi

echo "Backing up priv_validator_state.json..."
cp $HOME/.evmosd/data/priv_validator_state.json $HOME/.evmosd/priv_validator_state.json.backup
if [ $? -ne 0 ]; then
    echo "Error backing up priv_validator_state.json"
    exit 1
fi

echo "Resetting DB..."
evmosd tendermint unsafe-reset-all --home $HOME/.evmosd --keep-addr-book
if [ $? -ne 0 ]; then
    echo "Error resetting DB"
    exit 1
fi

echo "Extracting files from the archive..."
lz4 -d -c ./latest_snapshot.tar.lz4 | tar -xf - -C $HOME/.evmosd
if [ $? -ne 0 ]; then
    echo "Error extracting files from the archive"
    exit 1
fi

echo "Moving priv_validator_state.json back..."
mv $HOME/.evmosd/priv_validator_state.json.backup $HOME/.evmosd/data/priv_validator_state.json
if [ $? -ne 0 ]; then
    echo "Error moving priv_validator_state.json back"
    exit 1
fi

echo "Restarting the node..."
sudo systemctl restart ogd
if [ $? -ne 0 ]; then
    echo "Error restarting the node"
    exit 1
fi

echo "Checking the synchronization status..."

sleep 10

evmosd status | jq .SyncInfo
if [ $? -ne 0 ]; then
    echo "Error checking the synchronization status"
    exit 1
fi

echo "Please ensure your node is fully synced before proceeding to the next steps."

