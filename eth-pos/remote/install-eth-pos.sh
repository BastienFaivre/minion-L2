#!/bin/bash
#===============================================================================
# Author: Bastien Faivre
# Project: EPFL, DCL, Performance and Security Evaluation of Layer 2 Blockchain
#          Systems
# Date: July 2023
# Description: Install and build Ethereum Proof of Stake
#===============================================================================

#===============================================================================
# IMPORTS
#===============================================================================

. eth-pos/constants.sh
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
  sudo apt-get install -y git make build-essential python3 python3-pip gcc g++ \
    cmake pkg-config llvm-dev libclang-dev clang protobuf-compiler jq
  sudo pip3 install web3
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source ${HOME}/.cargo/env
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
# Initialize directories
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
# Clone and build Geth
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
clone_and_build_geth() {
  trap 'exit 1' ERR
  mkdir -p ${INSTALL_ROOT}/go-ethereum
  git clone ${GETH_URL} ${INSTALL_ROOT}/go-ethereum
  cd ${INSTALL_ROOT}/go-ethereum
  git checkout ${GETH_BRANCH}
  make all
  trap - ERR
}

#######################################
# Clone and build Lighthouse
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   None
#######################################
clone_and_build_lighthouse() {
  trap 'exit 1' ERR
  mkdir -p ${INSTALL_ROOT}/lighthouse
  git clone ${LIGHTHOUSE_URL} ${INSTALL_ROOT}/lighthouse
  cd ${INSTALL_ROOT}/lighthouse
  git checkout ${LIGHTHOUSE_BRANCH}
  make
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

utils::exec_cmd 'clone_and_build_geth' 'Clone and build Geth'

utils::exec_cmd 'clone_and_build_lighthouse' 'Clone and build Lighthouse'

trap - ERR
