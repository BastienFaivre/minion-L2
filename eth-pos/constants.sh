#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Variables used for Ethereum Proof of Stake
#===============================================================================

readonly INSTALL_FOLDER='install'
readonly INSTALL_ROOT="$INSTALL_FOLDER/eth-pos"
readonly DEPLOY_ROOT='deploy/eth-pos'
readonly CONFIG_ROOT="$DEPLOY_ROOT/config"
readonly CHAIN_ID=10
readonly GO_URL='https://go.dev/dl/go1.20.5.linux-amd64.tar.gz'
readonly GO_PATH='/usr/local/go/bin'
readonly GETH_URL='https://github.com/ethereum/go-ethereum'
readonly GETH_BRANCH='master'
readonly LIGHTHOUSE_URL='https://github.com/sigp/lighthouse.git'
readonly LIGHTHOUSE_BRANCH='stable'
readonly ACCOUNT_BALANCE=10000000000000000000 # 10 ether
readonly MASTER_BALANCE=1000000000000000000000 # 1000 ether
readonly GETH_ADDR=0.0.0.0
readonly GETH_AUTHRPC_PORT=8551
readonly GETH_PORT=30303
readonly GETH_DISCOVERY_PORT=30303
readonly GETH_HTTP_PORT=8545
readonly GETH_WS_PORT=8546
