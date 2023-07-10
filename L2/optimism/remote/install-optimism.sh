#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Install and build Optimism Stack components
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
  sudo apt-get install -y git curl make jq direnv
  curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt-get install -y nodejs
  sudo npm install -g n && sudo n latest
  sudo npm install -g pnpm
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source ${HOME}/.cargo/env
  echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
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
  rm -rf ${INSTALL_FOLDER}/optimism ${INSTALL_FOLDER}/op-geth
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
  git clone ${OP_MONOREPO_URL} ${INSTALL_FOLDER}/optimism
  cd ${INSTALL_FOLDER}/optimism
  pnpm install
  pnpm install:foundry
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
  git clone ${OP_GETH_URL} ${INSTALL_FOLDER}/op-geth
  cd ${INSTALL_FOLDER}/op-geth
  make geth
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

trap - ERR
