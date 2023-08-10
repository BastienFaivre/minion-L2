#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: August 2023
# Description: Variables used for Optimism
#===============================================================================

readonly INSTALL_FOLDER='install'
readonly INSTALL_ROOT="${INSTALL_FOLDER}/optimism"
readonly DEPLOY_ROOT='deploy/optimism'
readonly CONFIG_ROOT="${DEPLOY_ROOT}/config"
readonly ETH_CHAIN_ID=2023
readonly OP_CHAIN_ID=2320
readonly GO_URL='https://go.dev/dl/go1.20.5.linux-amd64.tar.gz'
readonly GO_PATH='/usr/local/go/bin'
readonly OP_MONOREPO_URL='https://github.com/ethereum-optimism/optimism.git'
readonly OP_MONOREPO_BRANCH='master'
readonly OP_GETH_URL='https://github.com/ethereum-optimism/op-geth.git'
readonly OP_GETH_BRANCH='optimism'
readonly ADMIN_BALANCE=10 # ether
readonly BATCHER_BALANCE=10 # ether
readonly PROPOSER_BALANCE=10 # ether
readonly ZERO_BALANCE=10 # ether
readonly GETH_PORT=30305
readonly P2P_LISTEN_PORT=9222
