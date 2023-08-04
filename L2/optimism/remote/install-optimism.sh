#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: August 2023
# Description: Install and build Optimism
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

. L2/optimism/constants.sh
. scripts/utils.sh

#===============================================================================
# FUNCTIONS
#===============================================================================

#######################################
# Get the usage of the script
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes the usage to stdout
# Returns:
#   None
#######################################
usage() {
  echo "Usage: $(basename ${0})"
}

#######################################
# Install the necessary packages
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
install_necessary_packages() {
  trap 'exit 1' ERR
  sudo apt-get update
  sudo apt-get install -y git curl make jq direnv build-essential python3-pip
  if ! grep ~/.bashrc -e 'eval "$(direnv hook bash)"' &> /dev/null
  then
    echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
  fi
  curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt-get install -y nodejs
  sudo npm install -g n && sudo n latest
  sudo npm install -g pnpm yarn
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source ${HOME}/.cargo/env
  pip3 install web3 eth-account
  trap - ERR
}

#######################################
# Install Golang
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
install_go() {
  trap 'exit 1' ERR
  wget ${GO_URL} > /dev/null 2>&1
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf ${GO_URL##*/}
  rm ${GO_URL##*/}
  if ! grep ~/.profile -e ${GO_PATH} &> /dev/null
  then
    echo "export PATH=\$PATH:${GO_PATH}" >> ~/.profile
  fi
  source ~/.profile
  if ! command -v go &> /dev/null
  then
    utils::err 'function install_go(): Go command not found after installation'
    trap - ERR
    exit 1
  fi
  trap - ERR
}

#######################################
# Initialize the directories
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
initialize_directories() {
  trap 'exit 1' ERR
  mkdir -p ${INSTALL_FOLDER}
  rm -rf ${INSTALL_ROOT}
  mkdir -p ${INSTALL_ROOT}
  trap - ERR
}

#######################################
# Clone and build the Optimism monorepo
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
clone_and_build_OP_monorepo() {
  trap 'exit 1' ERR
  mkdir -p ${INSTALL_ROOT}/optimism
  git clone ${OP_MONOREPO_URL} ${INSTALL_ROOT}/optimism
  cd ${INSTALL_ROOT}/optimism
  pnpm install
  rm -rf ${HOME}/.foundry
  curl -L https://foundry.paradigm.xyz | bash
  export PATH="${PATH}:${HOME}/.foundry/bin"
  pnpm update:foundry
  make op-node op-batcher op-proposer
  pnpm build
  trap - ERR
}

#######################################
# Clone and build Optimism Geth
# Globals:
#   None
# Arguments:
#  None
# Outputs:
#   None
# Returns:
#   None
#######################################
clone_and_build_OP_geth() {
  trap 'exit 1' ERR
  mkdir -p ${INSTALL_ROOT}/op-geth
  git clone ${OP_GETH_URL} ${INSTALL_ROOT}/op-geth
  cd ${INSTALL_ROOT}/op-geth
  make geth
  trap - ERR
}

#######################################
# Build p2p tool
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
build_p2p_tool() {
  trap 'exit 1' ERR
  cd L2/optimism/remote
  rm -rf go.mod go.sum bin/p2p-tool
  go mod init p2p-tool
  go mod tidy
  go build -o bin/p2p-tool p2p-tool.go
  trap - ERR
}

#===============================================================================
# MAIN
#===============================================================================

if ! utils::check_args_eq 0 $#; then
  usage
  exit 1
fi

trap 'exit 1' ERR

utils::ask_sudo

utils::exec_cmd 'install_necessary_packages' 'Install necessary packages'

source ~/.profile
if ! command -v go &> /dev/null
then
  utils::exec_cmd 'install_go' 'Install Go'
  source ~/.profile
  if ! command -v go &> /dev/null
  then
    utils::err 'function main(): Go command not found after installation'
    trap - ERR
    exit 1
  fi
fi

utils::exec_cmd 'initialize_directories' 'Initialize directories'

utils::exec_cmd 'clone_and_build_OP_monorepo' 'Clone and build Optimism monorepo'

utils::exec_cmd 'clone_and_build_OP_geth' 'Clone and build Optimism Geth'

utils::exec_cmd 'build_p2p_tool' 'Build p2p tool'

trap - ERR
