#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: June 2023
# Description: Variables used in the remote scripts
#===============================================================================

readonly INSTALL_FOLDER='install'
readonly INSTALL_ROOT="$INSTALL_FOLDER/eth-poa"
readonly DEPLOY_ROOT='deploy/eth-poa'
readonly NETWORK_ROOT="$DEPLOY_ROOT/network"
readonly NETWORK_ID=10
readonly GO_URL='https://go.dev/dl/go1.20.5.linux-amd64.tar.gz'
readonly GO_PATH='/usr/local/go/bin'
readonly GETH_URL='https://github.com/ethereum/go-ethereum'
readonly GETH_BRANCH='master'
readonly ACCOUNT_BALANCE=1000000000000000000000000
