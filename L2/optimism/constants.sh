#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Variables used for Optimism
#===============================================================================

readonly INSTALL_FOLDER='install'
readonly DEPLOY_ROOT='deploy/optimism'
readonly NETWORK_ROOT="$DEPLOY_ROOT/network"
readonly CHAIN_ID=10
readonly OP_MONOREPO_URL='https://github.com/ethereum-optimism/optimism.git'
readonly OP_GETH_URL='https://github.com/ethereum-optimism/op-geth.git'
readonly GO_URL='https://go.dev/dl/go1.20.5.linux-amd64.tar.gz'
readonly GO_PATH='/usr/local/go/bin'
readonly ADMIN_BALANCE=10 # ether
readonly BATCHER_BALANCE=10
readonly PROPOSER_BALANCE=10
