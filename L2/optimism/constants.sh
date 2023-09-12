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
readonly ETH_CHAIN_ID=2023 # Customizable, but must be the same as CHAIN_ID in eth-pos/constants.sh
readonly OP_CHAIN_ID=2320 # Customizable
readonly GO_URL='https://go.dev/dl/go1.20.5.linux-amd64.tar.gz'
readonly GO_PATH='/usr/local/go/bin'
readonly OP_MONOREPO_URL='https://github.com/ethereum-optimism/optimism.git'
readonly OP_MONOREPO_BRANCH='master'
readonly OP_GETH_URL='https://github.com/ethereum-optimism/op-geth.git'
readonly OP_GETH_BRANCH='optimism'
readonly BRIDGE_BALANCE=10 # ether
readonly ADMIN_BALANCE=10 # ether
readonly BATCHER_BALANCE=10 # ether
readonly PROPOSER_BALANCE=10 # ether
readonly P2P_LISTEN_PORT=9222 # Customizable
